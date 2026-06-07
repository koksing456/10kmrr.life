import AppKit
import SwiftUI

@MainActor
final class LockScreenOverlayController {
    final class OverlayWindowState {
        let window: NSWindow
        var hasDelegatedWindow = false

        init(window: NSWindow) {
            self.window = window
        }
    }

    let model = MRRDisplayModel()
    var windowsByScreenID: [String: OverlayWindowState] = [:]
    var isLocked = false
    var lockStateTask: Task<Void, Never>?
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

    @objc func screenLocked() {
        guard !isLocked else { return }
        isLocked = true
        showOverlay(reason: "screen-locked")
        startLockStatePolling()
        Task {
            await model.refresh()
        }
    }

    @objc func screenUnlocked() {
        guard isLocked || windowsByScreenID.values.contains(where: { $0.window.isVisible }) else { return }
        isLocked = false
        stopLockStatePolling()
        hideOverlay()
    }

    func showOverlay(reason: String) {
        let screens = targetScreens()
        guard !screens.isEmpty else { return }

        let activeScreenIDs = Set(screens.map { screenID(for: $0) })
        for (screenID, state) in windowsByScreenID where !activeScreenIDs.contains(screenID) {
            state.window.orderOut(nil)
        }

        for screen in screens {
            let screenID = screenID(for: screen)
            let targetFrame = frame(for: screen)
            let state = windowsByScreenID[screenID] ?? {
                let newState = OverlayWindowState(window: makeOverlayWindow(frame: targetFrame, reason: reason))
                windowsByScreenID[screenID] = newState
                return newState
            }()

            state.window.setFrame(targetFrame, display: true)
            state.window.level = reason == "preview"
                ? .screenSaver
                : NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))

            delegateToLockScreenIfNeeded(state: state, reason: reason)
            state.window.orderFrontRegardless()
            DispatchQueue.main.async {
                state.window.orderFrontRegardless()
            }
        }

        AppLogger.log("overlay_shown", fields: [
            "reason": reason,
            "screens": "\(screens.count)",
            "style": OverlaySettingsStore.visualStyle.rawValue
        ])
    }

    func hideOverlay() {
        for state in windowsByScreenID.values {
            state.window.orderOut(nil)
        }
        AppLogger.log("overlay_hidden")
    }

    func makeOverlayWindow(frame: NSRect, reason: String) -> NSWindow {
        let newWindow = NSPanel(
            contentRect: frame,
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
        return newWindow
    }

    private func delegateToLockScreenIfNeeded(state: OverlayWindowState, reason: String) {
        guard reason != "preview", !state.hasDelegatedWindow else { return }
        do {
            guard let skyLight = SkyLightOperator.shared else {
                throw OverlayError.skylightUnavailable
            }
            try skyLight.delegateWindow(state.window)
            state.hasDelegatedWindow = true
        } catch {
            model.statusText = "Overlay fallback"
            model.errorText = debugMode
                ? "Private API path failed: \(AppLogger.errorKind(error))"
                : "Private glass fallback active"
            AppLogger.log("skylight_delegate_failed", fields: [
                "error": AppLogger.errorKind(error),
                "debug": debugMode ? "true" : "false"
            ])
        }
    }
}
