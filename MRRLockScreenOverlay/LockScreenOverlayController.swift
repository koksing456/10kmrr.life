import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class LockScreenOverlayController {
    private let model = MRRDisplayModel()
    private var window: NSWindow?
    private var hasDelegatedWindow = false
    private var isLocked = false
    private var lockStateTask: Task<Void, Never>?
    private var refreshTimer: Timer?

    func start(previewMode: Bool) {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )

        refreshTimer = Timer.scheduledTimer(withTimeInterval: OverlaySettingsStore.refreshIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.model.refresh()
            }
        }

        if !previewMode {
            Task {
                await model.refresh()
            }
        }

        if previewMode {
            showOverlay(reason: "preview")
        }
    }

    func refreshNow() {
        Task {
            await model.refresh()
        }
    }

    @objc private func screenLocked() {
        guard !isLocked else { return }
        isLocked = true
        showOverlay(reason: "screen-locked")
        startLockStatePolling()
        Task {
            await model.refresh()
        }
    }

    @objc private func screenUnlocked() {
        guard isLocked || window?.isVisible == true else { return }
        isLocked = false
        stopLockStatePolling()
        hideOverlay()
    }

    private func showOverlay(reason: String) {
        guard let screen = targetScreen(for: reason) else { return }
        let targetFrame = frame(for: screen)
        let overlayWindow: NSWindow

        if let window {
            overlayWindow = window
            overlayWindow.setFrame(targetFrame, display: true)
        } else {
            let newWindow = NSPanel(
                contentRect: targetFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newWindow.isReleasedWhenClosed = false
            newWindow.isOpaque = false
            newWindow.backgroundColor = .clear
            newWindow.level = reason == "preview"
                ? .screenSaver
                : NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            newWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            newWindow.isMovable = false
            newWindow.hasShadow = false
            newWindow.ignoresMouseEvents = true
            newWindow.canHide = false
            newWindow.hidesOnDeactivate = false
            newWindow.contentView = NSHostingView(rootView: MRRLockOverlayView(model: model))
            window = newWindow
            overlayWindow = newWindow
            hasDelegatedWindow = false
        }

        overlayWindow.level = reason == "preview"
            ? .screenSaver
            : NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))

        let shouldDelegateToSkyLight = reason != "preview"
        if shouldDelegateToSkyLight, !hasDelegatedWindow {
            do {
                guard let skyLight = SkyLightOperator.shared else {
                    throw OverlayError.skylightUnavailable
                }
                try skyLight.delegateWindow(overlayWindow)
                hasDelegatedWindow = true
            } catch {
                model.statusText = "Overlay fallback"
                model.errorText = error.localizedDescription
            }
        }

        overlayWindow.orderFrontRegardless()
        DispatchQueue.main.async {
            overlayWindow.orderFrontRegardless()
        }
        NSLog("%@: overlay shown: %@", appSubsystem, reason)
    }

    private func targetScreen(for reason: String) -> NSScreen? {
        if reason == "preview" {
            let mouseLocation = NSEvent.mouseLocation
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
                return screen
            }
        }
        return NSScreen.main
    }

    private func hideOverlay() {
        window?.orderOut(nil)
        NSLog("%@: overlay hidden", appSubsystem)
    }

    private func frame(for screen: NSScreen) -> NSRect {
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

    private func startLockStatePolling() {
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

    private func stopLockStatePolling() {
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
