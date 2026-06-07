import AppKit

let keychainService = "life.10kmrr.MRRLockScreenOverlay"
let legacyKeychainService = "life.10kmrr.StripeMRRScreenSaver"
let keychainAccount = "stripe_api_key"
let appSubsystem = "life.10kmrr.MRRLockScreenOverlay"
let usePrivateGlassComponent = CommandLine.arguments.contains("--private-glass")
let setupMode = CommandLine.arguments.contains("--setup")
