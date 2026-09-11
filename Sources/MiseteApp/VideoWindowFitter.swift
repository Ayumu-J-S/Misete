import AppKit
import SwiftUI
import MiseteCore

/// Measures the actual video viewport so toolbar/titlebar heights are not guessed.
struct VideoWindowFitter: NSViewRepresentable {
    let videoSize: CGSize?

    func makeNSView(context: Context) -> FittingView { FittingView() }

    func updateNSView(_ view: FittingView, context: Context) {
        view.videoSize = videoSize
        view.scheduleFit()
    }
}

final class FittingView: NSView {
    var videoSize: CGSize?
    private var appliedAspect: CGFloat?
    private var scheduled = false
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        appliedAspect = nil
        guard let window else { return }
        observers = [
            NotificationCenter.default.addObserver(
                forName: NSWindow.didEndLiveResizeNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.fit(preserveWidth: true) }
            },
            NotificationCenter.default.addObserver(
                forName: NSWindow.didExitFullScreenNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.fit() }
            }
        ]
        scheduleFit()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        scheduleFit()
    }

    func scheduleFit() {
        guard let videoSize, videoSize.width > 0, videoSize.height > 0 else {
            appliedAspect = nil
            return
        }
        let aspect = videoSize.width / videoSize.height
        guard aspect.isFinite,
              appliedAspect.map({ abs($0 - aspect) > 0.001 }) ?? true,
              !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduled = false
            self.fit()
        }
    }

    private func fit(preserveWidth: Bool = false) {
        guard let window, !window.styleMask.contains(.fullScreen),
              !window.inLiveResize, let screen = window.screen,
              let videoSize, videoSize.width > 0, videoSize.height > 0,
              bounds.height > 0 else { return }
        let chrome = max(0, window.frame.height - bounds.height)
        var reference = window.frame
        if preserveWidth {
            let height = reference.width * videoSize.height / videoSize.width + chrome
            reference.origin.y = reference.maxY - height
            reference.size.height = height
        }
        guard let fitted = VideoWindowGeometry.fittedFrame(
            windowFrame: reference, videoSize: videoSize, chromeHeight: chrome,
            visibleFrame: screen.visibleFrame, minimumVideoWidth: 260
        ) else { return }
        appliedAspect = videoSize.width / videoSize.height
        if abs(window.frame.width - fitted.width) > 0.5 ||
            abs(window.frame.height - fitted.height) > 0.5 ||
            abs(window.frame.minX - fitted.minX) > 0.5 ||
            abs(window.frame.minY - fitted.minY) > 0.5 {
            window.setFrame(fitted, display: true, animate: false)
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }
}
