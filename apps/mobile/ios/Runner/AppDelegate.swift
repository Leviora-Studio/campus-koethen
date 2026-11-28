import CoreNFC
import Flutter
import UIKit
import UserNotifications
// Nur fuer setPluginRegistrantCallback noetig — das Plugin registriert damit
// die Plugins im eigenen Isolate, wenn eine Benachrichtigung die App startet.
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let canteenCardReader = CanteenCardReader()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Ohne diese Zeile liefert iOS den Tap auf eine Benachrichtigung nicht an
    // die App aus; das Ziel-Routing bliebe still wirkungslos.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "campus_koethen/mensa_card",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler(canteenCardReader.handle)
  }
}

/// Reads only the public balance file. The card identifier is never accessed.
private final class CanteenCardReader: NSObject, NFCTagReaderSessionDelegate {
  private var session: NFCTagReaderSession?
  private var pending: FlutterResult?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "scan":
      guard pending == nil else {
        result(FlutterError(code: "busy", message: nil, details: nil))
        return
      }
      guard NFCTagReaderSession.readingAvailable,
            let reader = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: .main)
      else {
        result(FlutterError(code: "unavailable", message: nil, details: nil))
        return
      }
      pending = result
      session = reader
      let args = call.arguments as? [String: String]
      reader.alertMessage = args?["instructions"] ?? ""
      reader.begin()
    case "cancel":
      if let reader = session { finish(reader, error: "cancelled") }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

  func tagReaderSession(_ reader: NFCTagReaderSession, didInvalidateWithError error: Error) {
    let code: String
    switch (error as? NFCReaderError)?.code {
    case .readerSessionInvalidationErrorUserCanceled: code = "cancelled"
    case .readerSessionInvalidationErrorSessionTimeout: code = "timeout"
    default: code = "readFailed"
    }
    finish(reader, error: code, invalidate: false)
  }

  func tagReaderSession(_ reader: NFCTagReaderSession, didDetect tags: [NFCTag]) {
    guard reader === session else { return }
    guard tags.count == 1 else {
      reader.restartPolling()
      return
    }
    let tag = tags[0]
    guard case .miFare(let card) = tag, card.mifareFamily == .desfire else {
      finish(reader, error: "readFailed")
      return
    }
    reader.connect(to: tag) { [weak self] error in
      guard let self = self, reader === self.session else { return }
      guard error == nil else {
        self.finish(reader, error: "readFailed")
        return
      }
      // Select the InterCard purse, then get the value of its public file.
      let select = self.command(0x5A, data: [0x5F, 0x84, 0x15])
      card.sendMiFareISO7816Command(select) { data, sw1, sw2, error in
        guard reader === self.session else { return }
        guard error == nil, data.isEmpty, sw1 == 0x91, sw2 == 0 else {
          self.finish(reader, error: "readFailed")
          return
        }
        let getValue = self.command(0x6C, data: [1])
        card.sendMiFareISO7816Command(getValue) { data, sw1, sw2, error in
          guard error == nil, data.count == 4, sw1 == 0x91, sw2 == 0 else {
            self.finish(reader, error: "readFailed")
            return
          }
          self.finish(reader, value: data)
        }
      }
    }
  }

  private func command(_ instruction: UInt8, data: [UInt8]) -> NFCISO7816APDU {
    NFCISO7816APDU(
      instructionClass: 0x90, instructionCode: instruction,
      p1Parameter: 0, p2Parameter: 0, data: Data(data), expectedResponseLength: 256
    )
  }

  private func finish(
    _ reader: NFCTagReaderSession, value: Data? = nil,
    error: String = "readFailed", invalidate: Bool = true
  ) {
    guard reader === session, let result = pending else { return }
    pending = nil
    session = nil
    if invalidate { reader.invalidate() }
    if let value = value {
      result(FlutterStandardTypedData(bytes: value))
    } else {
      result(FlutterError(code: error, message: nil, details: nil))
    }
  }
}
