//
//  PrinterManager.swift
//  Printer
//
//  Created by gix on 12/8/16.
//  Copyright © 2016 Kevin. All rights reserved.
//

import Foundation

public class NetworkPrinterManager {

    public func connectNetwork(ip: String, port: Int) {
        let PORT = NWEndpoint.Port(String(port))
        let ipAddress = NWEndpoint.Host(ip)
        let queue = DispatchQueue(label: "TCP Client Queue")

        let tcp = NWProtocolTCP.Options.init()
        tcp.noDelay = true
        let params = NWParameters.init(tls: nil, tcp: tcp)
        networkConnection = NWConnection(to: NWEndpoint.hostPort(host: ipAddress, port: PORT!), using: params)
        networkConnection?.stateUpdateHandler = { (newState) in
        switch (newState) {
            case .ready:
            UserDefaults.standard.set(true, forKey: "isConnected")
            default:
            UserDefaults.standard.set(false, forKey: "isConnected")
            break
        }
    }

    networkConnection?.start(queue: queue)
  }

    public func print(_ ticket: Ticket) {
        let content = getTicketData(ticket)

        networkConnection?.send(content: content, completion: NWConnection.SendCompletion.contentProcessed(({ (NWError) in
            if (NWError == nil) {
                print("Data was sent to TCP destination ")
            } else {
                print("ERROR! Error when data (Type: Data) sending. NWError: \n \(NWError!)")
            }
        })))
   }
}
