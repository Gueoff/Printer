//
//  NetworkPrinterManager.swift
//  Printer
//
//  Created by Geoffrey Desbrosses on 19/09/2024.
//  Copyright © 2024 Kevin. All rights reserved.
//

import Foundation
import Network
import MobileCoreServices

public class NetworkPrinterManager {
    private var networkConnection: NWConnection?
    
    public enum TicketPrintError: Error {
        case networkError(NWError)
        case unknownError
    }

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

    public func print(_ ticket: Ticket) throws {
        let content = getTicketData(ticket)
        
        guard let connection = networkConnection else {
            throw TicketPrintError.unknownError
        }

        let dispatchGroup = DispatchGroup()
        var printError: Error?

        dispatchGroup.enter()

        connection.send(content: content, completion: NWConnection.SendCompletion.contentProcessed({ (nwError) in
            if let error = nwError {
                printError = TicketPrintError.networkError(error)
            }
            dispatchGroup.leave()
        }))

        dispatchGroup.wait()

        if let error = printError {
            throw error
        }
    }
    
    private func getTicketData(_ ticket: Ticket) -> Data {
      let encoding = String.Encoding.utf8
      let ticketData = ticket.data(using: encoding)
      var combinedData = ticketData.reduce(Data()) { (result, data) -> Data in
        var mutableResult = result
        mutableResult.append(data)
        return mutableResult
      }

        let paperCutCommand: [UInt8] = [0x1D, 0x56, 0x00]
        combinedData.append(Data(paperCutCommand))

      return combinedData
    }
}
