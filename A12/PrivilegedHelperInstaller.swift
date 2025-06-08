import Foundation
import Security
import ServiceManagement

class PrivilegedHelperManager {
    static let helperIdentifier = "com.flyingthacat.PowerEventPrivilegedHelper"
    
    static func installHelperTool() -> Bool {
        var authRef: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &authRef) == errAuthorizationSuccess else {
            return false
        }
        
        // For constant strings, we can use direct pointer access
        let kRightName = kSMRightBlessPrivilegedHelper as CFString
        guard let cString = CFStringGetCStringPtr(kRightName, CFStringBuiltInEncodings.UTF8.rawValue) else {
            return false
        }
        
        var authItem = AuthorizationItem(
            name: UnsafeRawPointer(cString).assumingMemoryBound(to: Int8.self),
            valueLength: 0,
            value: nil,
            flags: 0
        )
        
        var authRights = withUnsafeMutablePointer(to: &authItem) {
            AuthorizationRights(count: 1, items: $0)
        }
        
        guard AuthorizationCreate(&authRights, nil, [.interactionAllowed, .extendRights, .preAuthorize], &authRef) == errAuthorizationSuccess else {
            return false
        }
        
        var error: Unmanaged<CFError>?
        let success = SMJobBless(kSMDomainSystemLaunchd, helperIdentifier as CFString, authRef, &error)
        if !success, let error = error?.takeRetainedValue() {
            print("Error: \(error)")
        }
        return success
    }
    
    
    static func runHelperCommand(arguments: [String]) -> Bool {
        let helperURL = URL(fileURLWithPath: "/Library/PrivilegedHelperTools/com.flyingthacat.PowerEventPrivilegedHelper")
        
        let task = Process()
        task.executableURL = helperURL
        task.arguments = arguments
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("Failed to run helper: \(error)")
            return false
        }
    }
}
