import AppKit
import CoreFoundation
import Foundation

final class SkyLightOperator {
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
