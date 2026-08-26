// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import AppKit
import Foundation

private let fileManager = FileManager.default
private let mobileRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
private let sourceURL = mobileRoot
  .appendingPathComponent("assets/branding/campus-koethen-icon.png")

guard let source = NSImage(contentsOf: sourceURL) else {
  fatalError("Cannot read brand icon at \(sourceURL.path)")
}

private var proposedSourceRect = CGRect(origin: .zero, size: source.size)
guard let sourceImage = source.cgImage(
  forProposedRect: &proposedSourceRect,
  context: nil,
  hints: nil
) else {
  fatalError("Cannot decode brand icon")
}

/// Returns the bounds of pixels that visibly belong to the mark.
///
/// The source PNG has a transparent square canvas whose visible content is not
/// vertically centred. Centring that canvas therefore leaves less paper above
/// the mark than below it once iOS applies the launcher-icon mask. Measuring
/// the alpha bounds keeps the correction deterministic if the source is ever
/// exported again with different transparent margins.
private func visibleAlphaBounds(of image: CGImage) -> CGRect {
  let width = image.width
  let height = image.height
  let bytesPerRow = width * 4
  let pixels = UnsafeMutablePointer<UInt8>.allocate(
    capacity: bytesPerRow * height
  )
  pixels.initialize(repeating: 0, count: bytesPerRow * height)
  defer {
    pixels.deinitialize(count: bytesPerRow * height)
    pixels.deallocate()
  }

  guard let context = CGContext(
    data: pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else {
    fatalError("Cannot inspect brand icon")
  }
  context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

  var minX = width
  var minY = height
  var maxX = -1
  var maxY = -1
  for y in 0..<height {
    for x in 0..<width {
      let alpha = pixels[y * bytesPerRow + x * 4 + 3]
      if alpha > 8 {
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
      }
    }
  }

  guard maxX >= minX, maxY >= minY else {
    fatalError("Brand icon has no visible pixels")
  }
  return CGRect(
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1
  )
}

private let sourceVisibleBounds = visibleAlphaBounds(of: sourceImage)
private let sourceCenteringOffset = CGPoint(
  x: CGFloat(sourceImage.width) / 2 - sourceVisibleBounds.midX,
  y: CGFloat(sourceImage.height) / 2 - sourceVisibleBounds.midY
)

private let paper = NSColor(
  calibratedRed: 250.0 / 255.0,
  green: 247.0 / 255.0,
  blue: 248.0 / 255.0,
  alpha: 1
)

private func render(
  size: Int,
  contentScale: CGFloat,
  background: NSColor?,
  to relativePath: String
) throws {
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  let alphaInfo: CGImageAlphaInfo = background == nil
    ? .premultipliedLast
    : .noneSkipLast
  guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: alphaInfo.rawValue
  ) else {
    fatalError("Cannot create graphics context for \(relativePath)")
  }

  context.interpolationQuality = .high
  let canvas = CGRect(x: 0, y: 0, width: size, height: size)
  if let background {
    context.setFillColor(background.cgColor)
    context.fill(canvas)
  } else {
    context.clear(canvas)
  }

  let renderedSize = CGFloat(size) * contentScale
  let inset = (CGFloat(size) - renderedSize) / 2
  let sourceScaleX = renderedSize / CGFloat(sourceImage.width)
  let sourceScaleY = renderedSize / CGFloat(sourceImage.height)
  context.draw(
    sourceImage,
    in: CGRect(
      x: inset + sourceCenteringOffset.x * sourceScaleX,
      // Bitmap rows and the output PNG use opposite vertical origins.
      y: inset - sourceCenteringOffset.y * sourceScaleY,
      width: renderedSize,
      height: renderedSize
    )
  )

  guard let outputImage = context.makeImage() else {
    fatalError("Cannot create output image for \(relativePath)")
  }
  let bitmap = NSBitmapImageRep(cgImage: outputImage)
  guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Cannot encode \(relativePath)")
  }

  let output = mobileRoot.appendingPathComponent(relativePath)
  try fileManager.createDirectory(
    at: output.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try png.write(to: output, options: .atomic)
}

private let iosIcons: [(String, Int)] = [
  ("Icon-App-20x20@1x.png", 20),
  ("Icon-App-20x20@2x.png", 40),
  ("Icon-App-20x20@3x.png", 60),
  ("Icon-App-29x29@1x.png", 29),
  ("Icon-App-29x29@2x.png", 58),
  ("Icon-App-29x29@3x.png", 87),
  ("Icon-App-40x40@1x.png", 40),
  ("Icon-App-40x40@2x.png", 80),
  ("Icon-App-40x40@3x.png", 120),
  ("Icon-App-60x60@2x.png", 120),
  ("Icon-App-60x60@3x.png", 180),
  ("Icon-App-76x76@1x.png", 76),
  ("Icon-App-76x76@2x.png", 152),
  ("Icon-App-83.5x83.5@2x.png", 167),
  ("Icon-App-1024x1024@1x.png", 1024),
]

for (name, size) in iosIcons {
  try render(
    size: size,
    contentScale: 0.84,
    background: paper,
    to: "ios/Runner/Assets.xcassets/AppIcon.appiconset/\(name)"
  )
}

private let densities: [(String, Int, Int, Int)] = [
  ("mdpi", 48, 108, 120),
  ("hdpi", 72, 162, 180),
  ("xhdpi", 96, 216, 240),
  ("xxhdpi", 144, 324, 360),
  ("xxxhdpi", 192, 432, 480),
]

for (density, legacySize, foregroundSize, launchSize) in densities {
  let mipmap = "android/app/src/main/res/mipmap-\(density)"
  try render(
    size: legacySize,
    contentScale: 0.84,
    background: paper,
    to: "\(mipmap)/ic_launcher.png"
  )
  try render(
    size: legacySize,
    contentScale: 0.84,
    background: paper,
    to: "\(mipmap)/ic_launcher_round.png"
  )
  try render(
    size: foregroundSize,
    contentScale: 0.72,
    background: nil,
    to: "\(mipmap)/ic_launcher_foreground.png"
  )
  try render(
    size: launchSize,
    contentScale: 0.94,
    background: nil,
    to: "android/app/src/main/res/drawable-\(density)/launch_logo.png"
  )
}

for (name, size, scale) in [
  ("Icon-192.png", 192, 0.84),
  ("Icon-512.png", 512, 0.84),
  ("Icon-maskable-192.png", 192, 0.68),
  ("Icon-maskable-512.png", 512, 0.68),
] {
  try render(
    size: size,
    contentScale: scale,
    background: paper,
    to: "web/icons/\(name)"
  )
}

try render(
  size: 64,
  contentScale: 0.90,
  background: paper,
  to: "web/favicon.png"
)

for (name, size) in [
  ("LaunchImage.png", 168),
  ("LaunchImage@2x.png", 336),
  ("LaunchImage@3x.png", 504),
] {
  try render(
    size: size,
    contentScale: 0.94,
    background: nil,
    to: "ios/Runner/Assets.xcassets/LaunchImage.imageset/\(name)"
  )
}
