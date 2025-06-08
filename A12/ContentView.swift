//
//  ContentView.swift
//  A12
//
//  Created by FlyingThaCat on 07/06/25.
//

import SwiftUI
import ServiceManagement

struct ContentView: View {
    @State private var isHelperInstalled: Bool = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Privileged Helper Manager")
            
            if isHelperInstalled {
                Button("Uninstall Helper") {
                    ContentView.uninstallHelper()
                    isHelperInstalled = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding()
                
                Button("Schedule Wake") {
                    scheduleWake()
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                Button("Request Sleep") {
                    requestSleep()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            } else {
                Button("Install Helper") {
                    installHelper()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .padding()
        .onAppear {
            checkHelperStatus()
        }
        .alert("Helper Status", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func checkHelperStatus() {
        let helperURL = URL(fileURLWithPath: "/Library/PrivilegedHelperTools/com.flyingthacat.PowerEventPrivilegedHelper")
        isHelperInstalled = FileManager.default.fileExists(atPath: helperURL.path)
    }
    
    private func installHelper() {
        if PrivilegedHelperManager.installHelperTool() {
            alertMessage = "Helper installed successfully"
            isHelperInstalled = true
        } else {
            alertMessage = "Failed to install helper"
        }
        showAlert = true
    }
    
    static func uninstallHelper() -> Bool {
        let helperPath = "/Library/PrivilegedHelperTools/com.flyingthacat.PowerEventPrivilegedHelper"
        let plistPath = "/Library/LaunchDaemons/com.flyingthacat.PowerEventPrivilegedHelper.plist"
    
        let uninstallScript = """
        do shell script "
        /bin/launchctl unload '\(plistPath)' || true
        /bin/rm -f '\(helperPath)'
        /bin/rm -f '\(plistPath)'
        " with administrator privileges
        """
        
        let appleScript = NSAppleScript(source: uninstallScript)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            print("Uninstall failed: \(error)")
            return false
        }
        return true
    }
    func sendXPCCommand(command: String, seconds: Int = 0) {
        let connection = xpc_connection_create_mach_service(
            "com.flyingthacat.PowerEventPrivilegedHelper",
            DispatchQueue.main,
            UInt64(XPC_CONNECTION_MACH_SERVICE_PRIVILEGED)
        )
        
        xpc_connection_set_event_handler(connection, { event in
            if xpc_get_type(event) == XPC_TYPE_DICTIONARY {
                let result = xpc_dictionary_get_int64(event, "result")
                let message = String(cString: xpc_dictionary_get_string(event, "message")!)
                let cmd = String(cString: xpc_dictionary_get_string(event, "command")!)
                
                print("Received reply for command \(cmd): \(message) (result: \(result))")
            }
        })
        
        xpc_connection_resume(connection)
        
        let message = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_string(message, "command", command)
        
        if command == "wake" {
            xpc_dictionary_set_int64(message, "seconds", Int64(seconds))
        }
        
        xpc_connection_send_message(connection, message)
    }
//    let powerManager = PowerEventManager();
    
    private func scheduleWake() {
        sendXPCCommand(command: "wake", seconds: 5)
//        powerManager.scheduleWake(seconds: 10) { success, message in
//            if success {
//                alertMessage = "Wake scheduled successfully: \(message ?? "")"
//            } else {
//                alertMessage = "Failed to schedule wake: \(message ?? "Unknown error")"
//            }
//            showAlert = true
//            print("Wake scheduling \(success ? "succeeded" : "failed")")
//        }
    }

    private func requestSleep() {
        sendXPCCommand(command: "sleep")
//        powerManager.requestSleep { success, message in
//            if success {
//                alertMessage = "Sleep request succeeded: \(message ?? "")"
//            } else {
//                alertMessage = "Sleep request failed: \(message ?? "Unknown error")"
//            }
//            showAlert = true
//            print("Sleep request \(success ? "succeeded" : "failed")")
//        }
    }
}

#Preview {
    ContentView()
}
