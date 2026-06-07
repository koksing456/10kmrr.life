import AppKit
import CoreFoundation
import CoreGraphics
import Foundation
import ObjectiveC.runtime
import Security
import SwiftUI

private let keychainService = "life.10kmrr.StripeMRRScreenSaver"
private let keychainAccount = "stripe_api_key"
private let appSubsystem = "life.10kmrr.MRRLockScreenOverlay"
private let usePrivateGlassComponent = CommandLine.arguments.contains("--private-glass")
private let setupMode = CommandLine.arguments.contains("--setup")
private let overlayPanelSize = NSSize(width: 432, height: 176)

private enum OverlayError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case stripeHTTP(Int, String)
    case stripePermissionHint
    case stripePaginationLimit(String)
    case skylightUnavailable

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Stripe key is not configured. Run setup to add a restricted read-only key."
        case .invalidResponse:
            return "Stripe returned an invalid response."
        case let .stripeHTTP(status, message):
            return "Stripe returned HTTP \(status). \(message)"
        case .stripePermissionHint:
            return "Stripe key cannot read the required Billing resources. Check restricted key permissions."
        case let .stripePaginationLimit(status):
            return "Stripe pagination exceeded the local safety limit while reading \(status) subscriptions."
        case .skylightUnavailable:
            return "Private SkyLight APIs are unavailable on this macOS build."
        }
    }
}

private enum OverlayPlacement: String, CaseIterable, Identifiable {
    case high
    case center
    case low

    var id: String { rawValue }

    var label: String {
        switch self {
        case .high:
            return "Higher"
        case .center:
            return "Center"
        case .low:
            return "Lower"
        }
    }
}

private enum OverlaySettingsStore {
    private static let defaults = UserDefaults(suiteName: "life.10kmrr.MRRLockScreenOverlay.Settings") ?? .standard
    private static let refreshIntervalKey = "refreshIntervalSeconds"
    private static let placementKey = "placement"

    static var refreshIntervalSeconds: TimeInterval {
        let stored = defaults.integer(forKey: refreshIntervalKey)
        guard stored >= 60 else { return 300 }
        return TimeInterval(stored)
    }

    static var refreshIntervalMinutes: Int {
        get { Int(refreshIntervalSeconds / 60) }
        set {
            let bounded = max(1, min(newValue, 60))
            defaults.set(bounded * 60, forKey: refreshIntervalKey)
        }
    }

    static var placement: OverlayPlacement {
        get {
            guard let rawValue = defaults.string(forKey: placementKey),
                  let placement = OverlayPlacement(rawValue: rawValue)
            else {
                return .center
            }
            return placement
        }
        set {
            defaults.set(newValue.rawValue, forKey: placementKey)
        }
    }

    static func reset() {
        defaults.removeObject(forKey: refreshIntervalKey)
        defaults.removeObject(forKey: placementKey)
    }
}

@MainActor
private final class MRRDisplayModel: ObservableObject {
    @Published var result: MRRResult?
    @Published var lastUpdated: Date?
    @Published var staleSince: Date?
    @Published var statusText = "Preparing MRR"
    @Published var isRefreshing = false
    @Published var errorText: String?

    private let defaults = UserDefaults(suiteName: "life.10kmrr.MRRLockScreenOverlay.Cache") ?? .standard

    init() {
        loadCache()
    }

    var primaryValue: String {
        guard let result, !result.isEmpty else { return "--" }
        return result.minorUnitsByCurrency
            .sorted { $0.key < $1.key }
            .map { Self.format(minorUnits: $0.value, currency: $0.key) }
            .joined(separator: "  ")
    }

    var timestampText: String {
        guard let lastUpdated else { return "Waiting for first refresh" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "Updated \(formatter.string(from: lastUpdated))"
    }

    var detailText: String {
        if let errorText, result != nil {
            return "Showing cached value. \(errorText)"
        }
        if let errorText {
            return errorText
        }
        if isRefreshing {
            return "Refreshing Stripe subscriptions"
        }
        return "Stripe MRR"
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorText = nil
        statusText = "Refreshing"

        do {
            let apiKey = try KeychainStore.readStripeAPIKey()
            let client = StripeMRRClient(apiKey: apiKey)
            let fetched = try await client.fetchMRR()
            result = fetched
            lastUpdated = Date()
            staleSince = nil
            statusText = "Live"
            saveCache()
        } catch {
            staleSince = Date()
            statusText = result == nil ? "Needs attention" : "Stale"
            errorText = error.localizedDescription
        }

        isRefreshing = false
    }

    private static func format(minorUnits: Int64, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        let value = Decimal(minorUnits) / Decimal(100)
        return formatter.string(from: value as NSDecimalNumber) ?? "\(currency.uppercased()) \(value)"
    }

    private func loadCache() {
        guard let data = defaults.data(forKey: "lastGoodMRR"),
              let cached = try? JSONDecoder().decode(MRRResult.self, from: data)
        else {
            return
        }
        result = cached
        lastUpdated = defaults.object(forKey: "lastUpdated") as? Date
        statusText = "Cached"
    }

    private func saveCache() {
        guard let result, let data = try? JSONEncoder().encode(result) else { return }
        defaults.set(data, forKey: "lastGoodMRR")
        defaults.set(lastUpdated, forKey: "lastUpdated")
    }
}

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

@MainActor
private final class SetupModel: ObservableObject {
    let refreshIntervalOptions = [1, 5, 10, 15, 30]

    @Published var keyInput = ""
    @Published var statusText = ""
    @Published var testText = ""
    @Published var isConfigured = false
    @Published var isTesting = false
    @Published var refreshIntervalMinutes = 5
    @Published var placement = OverlayPlacement.center

    init() {
        refreshStatus()
        loadSettings()
    }

    func refreshStatus() {
        isConfigured = KeychainStore.stripeAPIKeyExists()
        statusText = isConfigured ? "Keychain key configured" : "Keychain key not configured"
    }

    func loadSettings() {
        let storedRefreshInterval = OverlaySettingsStore.refreshIntervalMinutes
        refreshIntervalMinutes = refreshIntervalOptions.contains(storedRefreshInterval) ? storedRefreshInterval : 5
        placement = OverlaySettingsStore.placement
    }

    func saveSettings() {
        OverlaySettingsStore.refreshIntervalMinutes = refreshIntervalMinutes
        OverlaySettingsStore.placement = placement
        testText = "Saved display settings. Restart installed overlay to apply them."
    }

    func resetSettings() {
        OverlaySettingsStore.reset()
        loadSettings()
        testText = "Reset display settings"
    }

    func saveKey() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        testText = ""

        guard !trimmed.isEmpty else {
            statusText = "Enter a restricted Stripe key before saving"
            return
        }

        guard !trimmed.hasPrefix("sk_") else {
            statusText = "Refused full-access Stripe secret key"
            return
        }

        do {
            try KeychainStore.saveStripeAPIKey(trimmed)
            keyInput = ""
            refreshStatus()
            testText = trimmed.hasPrefix("rk_")
                ? "Saved restricted key"
                : "Saved key. Prefix was not rk_, so verify it is restricted in Stripe."
        } catch {
            statusText = "Keychain save failed"
            testText = error.localizedDescription
        }
    }

    func deleteKey() {
        do {
            try KeychainStore.deleteStripeAPIKey()
            keyInput = ""
            refreshStatus()
            testText = "Removed Keychain key"
        } catch {
            statusText = "Keychain delete failed"
            testText = error.localizedDescription
        }
    }

    func testStripe() async {
        guard !isTesting else { return }
        isTesting = true
        testText = "Testing Stripe access"

        do {
            let apiKey = try KeychainStore.readStripeAPIKey()
            let result = try await StripeMRRClient(apiKey: apiKey).fetchMRR()
            let currencyCount = result.minorUnitsByCurrency.count
            testText = currencyCount == 1
                ? "Stripe test passed for 1 currency"
                : "Stripe test passed for \(currencyCount) currencies"
            refreshStatus()
        } catch {
            testText = error.localizedDescription
            refreshStatus()
        }

        isTesting = false
    }
}

private struct SetupWindowView: View {
    @StateObject private var model = SetupModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("10kmrr.life Setup")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("Store a restricted read-only Stripe key in macOS Keychain.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(model.isConfigured ? Color.green : Color.orange)
                        .frame(width: 9, height: 9)
                    Text(model.statusText)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("Use a restricted key with read access to Stripe Billing subscriptions and prices. Full-access sk_ keys are refused.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Stripe restricted key")
                    .font(.system(size: 13, weight: .semibold))
                SecureField("rk_live_...", text: $model.keyInput)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 10) {
                    Button("Save Key") {
                        model.saveKey()
                    }
                    .keyboardShortcut(.defaultAction)

                    Button(model.isTesting ? "Testing..." : "Test Stripe") {
                        Task {
                            await model.testStripe()
                        }
                    }
                    .disabled(model.isTesting || !model.isConfigured)

                    Button("Delete Key", role: .destructive) {
                        model.deleteKey()
                    }
                    .disabled(!model.isConfigured)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Overlay settings")
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 18) {
                    Picker("Refresh", selection: $model.refreshIntervalMinutes) {
                        ForEach(model.refreshIntervalOptions, id: \.self) { minutes in
                            Text("\(minutes)m").tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 236)

                    Picker("Position", selection: $model.placement) {
                        ForEach(OverlayPlacement.allCases) { placement in
                            Text(placement.label).tag(placement)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 222)
                }
                HStack(spacing: 10) {
                    Button("Save Settings") {
                        model.saveSettings()
                    }
                    Button("Reset Settings") {
                        model.resetSettings()
                    }
                }
                Text("Settings are stored locally and apply the next time the overlay starts.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if !model.testText.isEmpty {
                Text(model.testText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(26)
        .frame(width: 560)
    }
}

private enum KeychainStore {
    static func stripeAPIKeyExists() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    static func readStripeAPIKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else {
            throw OverlayError.missingAPIKey
        }
        return key
    }

    static func saveStripeAPIKey(_ key: String) throws {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
        }
    }

    static func deleteStripeAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}

private final class StripeMRRClient {
    private let apiKey: String
    private let session: URLSession
    private let maxPagesPerStatus = 100

    private struct StripeSubscriptionPage {
        var subscriptions: [[String: Any]]
        var hasMore: Bool
    }

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    func fetchMRR() async throws -> MRRResult {
        var subscriptions: [[String: Any]] = []
        try await fetchAll(status: "active", into: &subscriptions)
        try await fetchAll(status: "past_due", into: &subscriptions)
        return MRRCalculator.calculate(from: subscriptions)
    }

    private func fetchAll(status: String, into subscriptions: inout [[String: Any]]) async throws {
        var startingAfter: String?

        for _ in 0..<maxPagesPerStatus {
            let page = try await fetchPage(status: status, startingAfter: startingAfter)
            subscriptions.append(contentsOf: page.subscriptions)

            guard page.hasMore else { return }
            guard let lastID = page.subscriptions.last?["id"] as? String else {
                throw OverlayError.invalidResponse
            }
            startingAfter = lastID
        }

        throw OverlayError.stripePaginationLimit(status)
    }

    private func fetchPage(status: String, startingAfter: String?) async throws -> StripeSubscriptionPage {
        var components = URLComponents(string: "https://api.stripe.com/v1/subscriptions")!
        var queryItems = [
            URLQueryItem(name: "status", value: status),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "expand[]", value: "data.items.data.price"),
            URLQueryItem(name: "expand[]", value: "data.discount.coupon")
        ]
        if let startingAfter {
            queryItems.append(URLQueryItem(name: "starting_after", value: startingAfter))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OverlayError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw OverlayError.stripePermissionHint
            }
            throw OverlayError.stripeHTTP(http.statusCode, Self.safeStripeErrorMessage(from: data))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OverlayError.invalidResponse
        }

        let page = json["data"] as? [[String: Any]] ?? []
        let hasMore = (json["has_more"] as? NSNumber)?.boolValue ?? false
        return StripeSubscriptionPage(subscriptions: page, hasMore: hasMore)
    }

    private static func safeStripeErrorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any]
        else {
            return "No public error message was available."
        }

        let type = error["type"] as? String
        let code = error["code"] as? String
        let message = (error["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let publicParts = [type, code, message]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        guard !publicParts.isEmpty else {
            return "No public error message was available."
        }

        let joined = publicParts.joined(separator: ": ")
        if joined.count > 220 {
            return String(joined.prefix(217)) + "..."
        }
        return joined
    }
}

private final class SkyLightOperator {
    static let shared = SkyLightOperator()

    private typealias SLSMainConnectionID = @convention(c) () -> Int32
    private typealias SLSSpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias SLSSpaceSetAbsoluteLevel = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias SLSShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias SLSSpaceAddWindowsAndRemoveFromSpaces = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    private let connection: Int32
    private let space: Int32
    private let addWindows: SLSSpaceAddWindowsAndRemoveFromSpaces

    private init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW),
              let mainConnectionSymbol = dlsym(handle, "SLSMainConnectionID"),
              let createSymbol = dlsym(handle, "SLSSpaceCreate"),
              let levelSymbol = dlsym(handle, "SLSSpaceSetAbsoluteLevel"),
              let showSymbol = dlsym(handle, "SLSShowSpaces"),
              let addSymbol = dlsym(handle, "SLSSpaceAddWindowsAndRemoveFromSpaces")
        else {
            return nil
        }

        let mainConnection = unsafeBitCast(mainConnectionSymbol, to: SLSMainConnectionID.self)
        let createSpace = unsafeBitCast(createSymbol, to: SLSSpaceCreate.self)
        let setLevel = unsafeBitCast(levelSymbol, to: SLSSpaceSetAbsoluteLevel.self)
        let showSpaces = unsafeBitCast(showSymbol, to: SLSShowSpaces.self)
        addWindows = unsafeBitCast(addSymbol, to: SLSSpaceAddWindowsAndRemoveFromSpaces.self)

        connection = mainConnection()
        space = createSpace(connection, 1, 0)
        _ = setLevel(connection, space, 400)
        _ = showSpaces(connection, [space] as CFArray)
    }

    func delegateWindow(_ window: NSWindow) throws {
        guard window.windowNumber > 0 else { return }
        _ = addWindows(connection, space, [window.windowNumber] as CFArray, 7)
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
