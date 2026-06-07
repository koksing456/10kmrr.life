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

private enum OverlayError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case stripeHTTP(Int, String)
    case stripePermissionHint
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
        case .skylightUnavailable:
            return "Private SkyLight APIs are unavailable on this macOS build."
        }
    }
}

private struct MRRResult: Codable, Equatable {
    var minorUnitsByCurrency: [String: Int64]
    var excludedMeteredItems: Int
    var excludedFreeItems: Int

    var isEmpty: Bool {
        minorUnitsByCurrency.isEmpty
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

    private let panelWidth: CGFloat = 432
    private let panelHeight: CGFloat = 176
    private let cornerRadius: CGFloat = 34

    @ViewBuilder
    var body: some View {
        Group {
            if usePrivateGlassComponent {
                PrivateGlassBackground(variant: 11, cornerRadius: cornerRadius) {
                    panelContent
                }
                .frame(width: panelWidth, height: panelHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                panelContent
                    .background(stableFrostedBackground)
                    .frame(width: panelWidth, height: panelHeight)
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
        .frame(width: panelWidth, height: panelHeight)
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

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
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
        let size = NSSize(width: 350, height: 180)
        let frame = screen.frame
        let originY = frame.minY + (frame.height / 2) - size.height - 60
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
    @Published var keyInput = ""
    @Published var statusText = ""
    @Published var testText = ""
    @Published var isConfigured = false
    @Published var isTesting = false

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        isConfigured = KeychainStore.stripeAPIKeyExists()
        statusText = isConfigured ? "Keychain key configured" : "Keychain key not configured"
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
        .frame(width: 520)
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

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    func fetchMRR() async throws -> MRRResult {
        var subscriptions: [[String: Any]] = []
        try await fetch(status: "active", startingAfter: nil, into: &subscriptions)
        try await fetch(status: "past_due", startingAfter: nil, into: &subscriptions)
        return MRRCalculator.calculate(from: subscriptions)
    }

    private func fetch(status: String, startingAfter: String?, into subscriptions: inout [[String: Any]]) async throws {
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
        subscriptions.append(contentsOf: page)
        let hasMore = (json["has_more"] as? NSNumber)?.boolValue ?? false
        if hasMore, let lastID = page.last?["id"] as? String {
            try await fetch(status: status, startingAfter: lastID, into: &subscriptions)
        }
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

private enum MRRCalculator {
    static func calculate(from subscriptions: [[String: Any]]) -> MRRResult {
        var totals: [String: Int64] = [:]
        var excludedMetered = 0
        var excludedFree = 0

        for subscription in subscriptions {
            let status = subscription["status"] as? String ?? ""
            guard status == "active" || status == "past_due" else { continue }

            let itemsContainer = subscription["items"] as? [String: Any]
            let items = itemsContainer?["data"] as? [[String: Any]] ?? []
            for item in items {
                let price = item["price"] as? [String: Any] ?? [:]
                let recurring = price["recurring"] as? [String: Any] ?? [:]
                if (recurring["usage_type"] as? String) == "metered" {
                    excludedMetered += 1
                    continue
                }

                let unitAmount = unitAmountMinorUnits(from: price)
                let quantity = (item["quantity"] as? NSNumber)?.intValue ?? 1
                if unitAmount <= 0 || quantity <= 0 {
                    excludedFree += 1
                    continue
                }

                var monthlyAmount = monthlyAmountMinorUnits(unitAmount: unitAmount, recurring: recurring) * Double(quantity)
                monthlyAmount = applyDiscounts(subscription["discounts"], to: monthlyAmount)
                if let legacyDiscount = subscription["discount"] as? [String: Any] {
                    monthlyAmount = applyDiscounts([legacyDiscount], to: monthlyAmount)
                }
                monthlyAmount = applyDiscounts(item["discounts"], to: monthlyAmount)

                let currency = (price["currency"] as? String ?? "").lowercased()
                guard !currency.isEmpty, monthlyAmount > 0 else { continue }
                totals[currency, default: 0] += Int64(monthlyAmount.rounded())
            }
        }

        return MRRResult(
            minorUnitsByCurrency: totals,
            excludedMeteredItems: excludedMetered,
            excludedFreeItems: excludedFree
        )
    }

    private static func unitAmountMinorUnits(from price: [String: Any]) -> Double {
        if let decimal = price["unit_amount_decimal"] as? String {
            return Double(decimal) ?? 0
        }
        return (price["unit_amount"] as? NSNumber)?.doubleValue ?? 0
    }

    private static func monthlyAmountMinorUnits(unitAmount: Double, recurring: [String: Any]) -> Double {
        let interval = recurring["interval"] as? String ?? "month"
        let count = max(1, (recurring["interval_count"] as? NSNumber)?.intValue ?? 1)

        switch interval {
        case "day":
            return unitAmount * 30 / Double(count)
        case "week":
            return unitAmount * (52 / 12) / Double(count)
        case "year":
            return unitAmount / (12 * Double(count))
        default:
            return unitAmount / Double(count)
        }
    }

    private static func applyDiscounts(_ object: Any?, to amount: Double) -> Double {
        var discounts: [[String: Any]] = []
        if let array = object as? [[String: Any]] {
            discounts = array
        } else if let container = object as? [String: Any] {
            discounts = container["data"] as? [[String: Any]] ?? [container]
        }

        var result = amount
        for discount in discounts {
            guard let coupon = discount["coupon"] as? [String: Any] else { continue }
            if let percent = (coupon["percent_off"] as? NSNumber)?.doubleValue {
                result *= max(0, 1 - percent / 100)
            }
            if let amountOff = (coupon["amount_off"] as? NSNumber)?.doubleValue {
                let duration = coupon["duration"] as? String ?? ""
                if duration == "forever" || duration.isEmpty {
                    result = max(0, result - amountOff)
                }
            }
        }
        return result
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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 410),
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

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
