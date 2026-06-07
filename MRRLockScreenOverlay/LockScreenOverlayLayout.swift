import AppKit
import CoreGraphics

extension LockScreenOverlayController {
    func targetScreens() -> [NSScreen] {
        switch OverlaySettingsStore.displayMode {
        case .all:
            return NSScreen.screens
        case .cursor:
            let mouseLocation = NSEvent.mouseLocation
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
                return [screen]
            }
            return NSScreen.main.map { [$0] } ?? []
        case .main:
            return NSScreen.main.map { [$0] } ?? []
        }
    }

    func screenID(for screen: NSScreen) -> String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = screen.deviceDescription[key] as? NSNumber {
            return "display-\(number.uint32Value)"
        }
        return "frame-\(Int(screen.frame.minX))-\(Int(screen.frame.minY))-\(Int(screen.frame.width))-\(Int(screen.frame.height))"
    }

    func frame(for screen: NSScreen) -> NSRect {
        let size = OverlaySettingsStore.panelSize
        let frame = screen.frame
        let sideMargin = min(max(frame.width * 0.08, 56), 160)
        let originX: CGFloat
        switch OverlaySettingsStore.horizontalPlacement {
        case .left:
            originX = frame.minX + sideMargin
        case .center:
            originX = frame.midX - size.width / 2
        case .right:
            originX = frame.maxX - sideMargin - size.width
        }

        let originY: CGFloat
        switch OverlaySettingsStore.placement {
        case .high:
            originY = frame.minY + (frame.height / 2) + 28
        case .center:
            originY = frame.minY + (frame.height / 2) - size.height - 60
        case .low:
            originY = frame.minY + (frame.height / 2) - size.height - 180
        }

        return NSRect(
            x: originX,
            y: originY,
            width: size.width,
            height: size.height
        )
    }

    func startLockStatePolling() {
        lockStateTask?.cancel()
        lockStateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    guard let self, self.isLocked else { return }
                    if !Self.isSessionScreenLocked() {
                        self.screenUnlocked()
                    }
                }
            }
        }
    }

    func stopLockStatePolling() {
        lockStateTask?.cancel()
        lockStateTask = nil
    }

    private static func isSessionScreenLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }
        return session["CGSSessionScreenIsLocked"] as? Bool ?? false
    }
}
