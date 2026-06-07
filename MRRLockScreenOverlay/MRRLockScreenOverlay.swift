import AppKit
import CoreFoundation
import CoreGraphics
import Foundation
import ObjectiveC.runtime
import SwiftUI

private let overlayPanelSize = NSSize(width: 432, height: 176)

private struct MRRLockOverlayView: View {
    @ObservedObject var model: MRRDisplayModel
    @State private var pulse = false

    private let cornerRadius: CGFloat = 34

    @ViewBuilder
    var body: some View {
        Group {
            if usePrivateGlassComponent {
                PrivateGlassBackground(variant: 11, cornerRadius: cornerRadius) {
                    panelContent
                }
                .frame(width: overlayPanelSize.width, height: overlayPanelSize.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                panelContent
                    .background(stableFrostedBackground)
                    .frame(width: overlayPanelSize.width, height: overlayPanelSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .overlay(panelEdgeTreatment)
        .environment(\.colorScheme, .dark)
        .shadow(color: .black.opacity(0.24), radius: 34, x: 0, y: 22)
        .onAppear {
            pulse = true
        }
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 9) {
                Text("Stripe MRR")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                statusDot
                Spacer(minLength: 0)
            }

            Text(model.primaryValue)
                .font(.system(size: 54, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.50)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)

            HStack(alignment: .center, spacing: 12) {
                Text(model.timestampText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .monospacedDigit()
                Spacer(minLength: 0)
                if let footerStatusText {
                    Text(footerStatusText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(width: overlayPanelSize.width, height: overlayPanelSize.height)
        .background(Color.white.opacity(usePrivateGlassComponent ? 0.00 : 0.035))
    }

    private var stableFrostedBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.12),
                            .white.opacity(0.02),
                            .black.opacity(0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var panelEdgeTreatment: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(0.70),
                        .white.opacity(0.18),
                        .white.opacity(0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.25
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.20), .white.opacity(0.00)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.black.opacity(0.00), .black.opacity(0.14)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
            }
    }

    private var statusDot: some View {
        ZStack {
            Circle()
                .fill(dotColor.opacity(0.20))
                .frame(width: 18, height: 18)
                .scaleEffect(pulse ? 1.18 : 0.82)
                .opacity(pulse ? 0.55 : 0.90)
            Circle()
                .fill(dotColor)
                .frame(width: 7.5, height: 7.5)
        }
        .shadow(color: dotColor.opacity(0.42), radius: 7)
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
    }

    private var dotColor: Color {
        if model.isRefreshing { return .yellow }
        if model.errorText != nil { return .orange }
        return .green
    }

    private var footerStatusText: String? {
        if model.errorText != nil, model.result != nil { return "Cached" }
        if model.errorText != nil { return "Needs attention" }
        if model.isRefreshing { return "Refreshing" }
        return nil
    }
}

private final class PrivateGlassContainerView: NSView {
    weak var glassView: NSView?
    var hostingView: NSHostingView<AnyView>?
    private var observedBackdropLayers: [CALayer] = []
    private var hasScheduledBackdropSetup = false

    deinit {
        removeBackdropObservers()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleBackdropSetup()
    }

    override func layout() {
        super.layout()
        scheduleBackdropSetup()
    }

    private func scheduleBackdropSetup() {
        guard !hasScheduledBackdropSetup else { return }
        hasScheduledBackdropSetup = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.hasScheduledBackdropSetup = false
            self.configureBackdropLayers()
        }
    }

    private func configureBackdropLayers() {
        guard let rootLayer = glassView?.layer else {
            scheduleBackdropSetup()
            return
        }
        setBackdropProperties(in: rootLayer)
        let layers = collectBackdropLayers(in: rootLayer)
        removeBackdropObservers()
        observedBackdropLayers = layers
        for layer in observedBackdropLayers {
            layer.addObserver(self, forKeyPath: "windowServerAware", options: [.new], context: nil)
            layer.addObserver(self, forKeyPath: "scale", options: [.new], context: nil)
        }
    }

    private func setBackdropProperties(in layer: CALayer) {
        if NSStringFromClass(type(of: layer)).contains("CABackdropLayer") {
            layer.setValue(true, forKey: "windowServerAware")
            layer.setValue(1.0, forKey: "scale")
        }
        layer.sublayers?.forEach { setBackdropProperties(in: $0) }
    }

    private func collectBackdropLayers(in layer: CALayer) -> [CALayer] {
        var result: [CALayer] = []
        if NSStringFromClass(type(of: layer)).contains("CABackdropLayer") {
            result.append(layer)
        }
        layer.sublayers?.forEach { result.append(contentsOf: collectBackdropLayers(in: $0)) }
        return result
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "windowServerAware" {
            if change?[.newKey] as? Bool == false {
                configureBackdropLayers()
            }
        } else if keyPath == "scale" {
            guard let layer = object as? CALayer else { return }
            if let scale = (change?[.newKey] as? NSNumber)?.doubleValue, scale != 1.0 {
                layer.setValue(1.0, forKey: "scale")
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    private func removeBackdropObservers() {
        for layer in observedBackdropLayers {
            layer.removeObserver(self, forKeyPath: "windowServerAware")
            layer.removeObserver(self, forKeyPath: "scale")
        }
        observedBackdropLayers.removeAll()
    }
}

private struct PrivateGlassBackground<Content: View>: NSViewRepresentable {
    let variant: Int
    let cornerRadius: CGFloat
    let content: Content

    init(variant: Int, cornerRadius: CGFloat, @ViewBuilder content: () -> Content) {
        self.variant = variant
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    func makeNSView(context: Context) -> NSView {
        if let glassType = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let container = PrivateGlassContainerView(frame: .zero)
            container.translatesAutoresizingMaskIntoConstraints = false
            let glass = glassType.init(frame: .zero)
            glass.translatesAutoresizingMaskIntoConstraints = false
            glass.setValue(cornerRadius, forKey: "cornerRadius")
            setPrivateVariant(variant, on: glass)

            let hosting = NSHostingView(rootView: AnyView(content))
            hosting.translatesAutoresizingMaskIntoConstraints = false
            glass.setValue(hosting, forKey: "contentView")

            container.addSubview(glass)
            NSLayoutConstraint.activate([
                glass.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                glass.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                glass.topAnchor.constraint(equalTo: container.topAnchor),
                glass.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])

            container.glassView = glass
            container.hostingView = hosting
            return container
        }

        let fallback = NSVisualEffectView()
        fallback.material = .underWindowBackground
        fallback.blendingMode = .behindWindow
        fallback.state = .active

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        fallback.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: fallback.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: fallback.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: fallback.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: fallback.bottomAnchor)
        ])
        return fallback
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let container = nsView as? PrivateGlassContainerView {
            container.glassView?.setValue(cornerRadius, forKey: "cornerRadius")
            if let glass = container.glassView {
                setPrivateVariant(variant, on: glass)
            }
            container.hostingView?.rootView = AnyView(content)
            return
        }

        if let visualEffect = nsView as? NSVisualEffectView,
           let hosting = visualEffect.subviews.compactMap({ $0 as? NSHostingView<Content> }).first {
            hosting.rootView = content
        }
    }

    private func setPrivateVariant(_ value: Int, on object: AnyObject) {
        let selector = NSSelectorFromString("set_variant:")
        guard let method = class_getInstanceMethod(object_getClass(object), selector) else {
            return
        }
        typealias Setter = @convention(c) (AnyObject, Selector, Int) -> Void
        let implementation = method_getImplementation(method)
        let setter = unsafeBitCast(implementation, to: Setter.self)
        setter(object, selector, value)
    }
}

@MainActor
private final class LockScreenOverlayController {
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
        let size = overlayPanelSize
        let frame = screen.frame
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
            x: frame.midX - size.width / 2,
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

private final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor private var overlayController: LockScreenOverlayController?
    @MainActor private var setupWindow: NSWindow?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let previewMode = CommandLine.arguments.contains("--preview")
        NSApp.setActivationPolicy(previewMode || setupMode ? .regular : .accessory)
        if previewMode || setupMode {
            NSApp.activate(ignoringOtherApps: true)
        }

        if setupMode {
            showSetupWindow()
            return
        }

        let controller = LockScreenOverlayController()
        overlayController = controller
        controller.start(previewMode: previewMode)
    }

    @MainActor
    private func showSetupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "10kmrr.life Setup"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SetupWindowView())
        window.makeKeyAndOrderFront(nil)
        setupWindow = window
    }
}

@main
private enum MRRLockScreenOverlayApplication {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}
