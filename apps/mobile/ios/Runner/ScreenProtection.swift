import Flutter
import UIKit

/// Keeps sensitive screens out of the iOS app-switcher snapshot.
///
/// iOS has no `FLAG_SECURE`. What it does have is a snapshot taken the moment
/// the app resigns active, which is exactly what the switcher shows — so the
/// protection is a cover view placed over the window for that moment and taken
/// away again on the way back. Screenshots themselves stay possible on iOS;
/// this is deliberate and matches the decision to protect the switcher rather
/// than to lock the platform down.
///
/// Applied **selectively**: only while a screen showing a university password
/// or a copy of a student ID is on screen. A timetable stays shareable.
///
/// Counted rather than boolean, so two protected screens on the stack cannot
/// have the upper one's disposal expose the lower one.
final class ScreenProtection {
    static let shared = ScreenProtection()

    static let channelName = "dev.erikengler.campuskoethen/screen_protection"

    private var requests = 0
    private var cover: UIView?
    private var observing = false

    private init() {}

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return }
            switch call.method {
            case "acquire":
                self.requests += 1
                self.startObservingIfNeeded()
                result(nil)
            case "release":
                // Never below zero: a release without a matching acquire would
                // leave the counter negative and the next acquire ineffective.
                if self.requests > 0 { self.requests -= 1 }
                if self.requests == 0 { self.removeCover() }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func startObservingIfNeeded() {
        guard !observing else { return }
        observing = true
        let centre = NotificationCenter.default
        centre.addObserver(
            self,
            selector: #selector(willResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        centre.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func willResignActive() {
        guard requests > 0, cover == nil else { return }
        guard let window = Self.keyWindow() else { return }

        // An opaque view rather than a blur: a blur of a password field can
        // still leak its shape and length, and the switcher thumbnail is small
        // enough that a plain cover costs nothing in recognisability — the app
        // name is shown beside it either way.
        let view = UIView(frame: window.bounds)
        view.backgroundColor = window.backgroundColor ?? .systemBackground
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(view)
        cover = view
    }

    @objc private func didBecomeActive() {
        removeCover()
    }

    private func removeCover() {
        cover?.removeFromSuperview()
        cover = nil
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}
