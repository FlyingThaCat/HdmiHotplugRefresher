//
//  PowerEventManager.swift
//  A12
//
//  Created by FlyingThaCat on 08/06/25.
//

import Foundation

@objc protocol PowerEventPrivilegedProtocol {
    func sendCommand(command: String, seconds: Int, withReply: @escaping ([String: Any]) -> Void)
}

class PowerEventManager {
    private let connection: NSXPCConnection

    init() {
        connection = NSXPCConnection(machServiceName: "com.flyingthacat.PowerEventPrivilegedHelper")
        
        let interface = NSXPCInterface(with: PowerEventPrivilegedProtocol.self)
        
        connection.remoteObjectInterface = interface
        connection.resume()
    }

    func scheduleWake(seconds: Int, completion: @escaping (Bool, String) -> Void) {
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            completion(false, "Connection failed: \(error.localizedDescription)")
        }) as? PowerEventPrivilegedProtocol else {
            completion(false, "Invalid proxy")
            return
        }

        proxy.sendCommand(command: "wake", seconds: seconds) { response in
            let result = (response["result"] as? NSNumber)?.intValue ?? -1
            let message = response["message"] as? String ?? "Unknown response"
            completion(result == 0, message)
        }
    }

    func requestSleep(completion: @escaping (Bool, String) -> Void) {
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            completion(false, "Connection failed: \(error.localizedDescription)")
        }) as? PowerEventPrivilegedProtocol else {
            completion(false, "Invalid proxy")
            return
        }

        proxy.sendCommand(command: "sleep", seconds: 0) { response in
            let result = (response["result"] as? NSNumber)?.intValue ?? -1
            let message = response["message"] as? String ?? "Unknown response"
            completion(result == 0, message)
        }
    }

    deinit {
        connection.invalidate()
    }
}
