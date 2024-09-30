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

@available(iOS 12.0, *)
public class NetworkPrinterManager {
    private var networkConnection: NWConnection?
    
    public init() {}

    public enum TicketPrintError: Error {
        case networkError(NWError)
        case notConnected
        case unknownError
        case port
        case connection(NWError)
    }

    public var onConnectionStateChange: ((NWConnection.State) -> Void)?

    public func getNetworkConnection() -> NWConnection? {
        return self.networkConnection
    }
    
    public func getConnectionState() -> NWConnection.State? {
        return self.networkConnection?.state
    }

    public func connect(ip: String, port: Int) throws {
        guard let PORT = NWEndpoint.Port("\(port)") else {
            throw TicketPrintError.port
        }

        let ipAddress = NWEndpoint.Host(ip)
        let queue = DispatchQueue(label: "TCP Client Queue")

        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        let params = NWParameters(tls: nil, tcp: tcp)
        
        networkConnection = NWConnection(to: NWEndpoint.hostPort(host: ipAddress, port: PORT), using: params)
        networkConnection?.stateUpdateHandler = { [weak self] (newState) in
            self?.onConnectionStateChange?(newState)
            
            switch newState {
            case .ready:
                UserDefaults.standard.set(true, forKey: "isConnected")
            case .failed:
                UserDefaults.standard.set(false, forKey: "isConnected")
            case .cancelled:
                UserDefaults.standard.set(false, forKey: "isConnected")
            default:
                UserDefaults.standard.set(false, forKey: "isConnected")
            }
        }

        networkConnection?.start(queue: queue)
    }

    public func print(_ ticket: Ticket) throws {
        guard let connection = networkConnection else {
            throw TicketPrintError.notConnected
        }

        if connection.state != .ready {
            throw TicketPrintError.notConnected
        }

        let content = getTicketData(ticket)

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
        let combinedData = ticketData.reduce(Data()) { (result, data) -> Data in
            var mutableResult = result
            mutableResult.append(data)
            return mutableResult
        }

        let paperCutCommand: [UInt8] = [0x1D, 0x56, 0x00]
        combinedData.append(Data(paperCutCommand))

        return combinedData
    }
}
