import Foundation

public enum VideoWindowGeometry {
    public static func fittedFrame(
        windowFrame: CGRect,
        videoSize: CGSize,
        chromeHeight: CGFloat,
        visibleFrame: CGRect,
        minimumVideoWidth: CGFloat = 360
    ) -> CGRect? {
        guard isFinite(windowFrame),
              isFinite(visibleFrame),
              videoSize.width.isFinite,
              videoSize.height.isFinite,
              chromeHeight.isFinite,
              minimumVideoWidth.isFinite,
              windowFrame.size.width > 0,
              windowFrame.size.height > chromeHeight,
              videoSize.width > 0,
              videoSize.height > 0,
              chromeHeight >= 0,
              minimumVideoWidth >= 0,
              visibleFrame.size.width > 0,
              visibleFrame.size.height > chromeHeight else {
            return nil
        }

        let aspectRatio = videoSize.width / videoSize.height
        var videoHeight = windowFrame.size.height - chromeHeight
        var videoWidth = videoHeight * aspectRatio
        guard aspectRatio.isFinite, videoWidth.isFinite, videoWidth > 0 else { return nil }

        if videoWidth < minimumVideoWidth {
            let minimumScale = minimumVideoWidth / videoWidth
            videoWidth *= minimumScale
            videoHeight *= minimumScale
        }

        let maximumVideoHeight = visibleFrame.size.height - chromeHeight
        let fitScale = min(CGFloat(1), visibleFrame.size.width / videoWidth, maximumVideoHeight / videoHeight)
        videoWidth *= fitScale
        videoHeight *= fitScale
        let windowHeight = videoHeight + chromeHeight
        guard fitScale > 0,
              videoWidth.isFinite,
              windowHeight.isFinite,
              videoWidth > 0,
              windowHeight > chromeHeight else {
            return nil
        }

        let desiredX = windowFrame.origin.x + windowFrame.size.width / 2 - videoWidth / 2
        let desiredY = windowFrame.origin.y + windowFrame.size.height - windowHeight
        let maximumX = visibleFrame.origin.x + visibleFrame.size.width - videoWidth
        let maximumY = visibleFrame.origin.y + visibleFrame.size.height - windowHeight
        let x = clamp(desiredX, lower: visibleFrame.origin.x, upper: maximumX)
        let y = clamp(desiredY, lower: visibleFrame.origin.y, upper: maximumY)
        return CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: videoWidth, height: windowHeight))
    }

    private static func isFinite(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite &&
            rect.size.width.isFinite && rect.size.height.isFinite
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
