#!/usr/bin/env swift
import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-icon.swift OUTPUT_ICONSET_DIRECTORY\n", stderr)
    exit(64)
}

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

for (name, pixels) in sizes {
    let side = CGFloat(pixels)
    guard let image = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: image) else {
        throw CocoaError(.fileWriteUnknown)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let canvas = NSRect(x: 0, y: 0, width: side, height: side)
    NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.12, alpha: 1).setFill()
    NSBezierPath(roundedRect: canvas, xRadius: side * 0.22, yRadius: side * 0.22).fill()

    let back = NSRect(x: side * 0.20, y: side * 0.31, width: side * 0.48, height: side * 0.35)
    NSColor(calibratedRed: 0.37, green: 0.78, blue: 0.67, alpha: 1).setFill()
    NSBezierPath(roundedRect: back, xRadius: side * 0.055, yRadius: side * 0.055).fill()

    let front = NSRect(x: side * 0.33, y: side * 0.20, width: side * 0.48, height: side * 0.35)
    NSColor(calibratedRed: 0.86, green: 0.97, blue: 0.90, alpha: 1).setFill()
    NSBezierPath(roundedRect: front, xRadius: side * 0.055, yRadius: side * 0.055).fill()
    NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.12, alpha: 0.85).setStroke()
    let line = NSBezierPath()
    line.lineWidth = max(1, side * 0.018)
    line.move(to: NSPoint(x: side * 0.39, y: side * 0.29))
    line.line(to: NSPoint(x: side * 0.70, y: side * 0.29))
    line.stroke()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = image.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: destination.appendingPathComponent(name))
}
