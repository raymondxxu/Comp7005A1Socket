//
//  Socket.swift
//  
//
//  Created by Raymond Xu on 2022-10-02.
//
import Foundation

public enum Const{
    static var sockaddr_inSize = socklen_t(MemoryLayout<sockaddr_in>.size)
}

public enum SocketError: Error {
    case SocketCreationError
    case BindError
    case ListenError
    case AcceptError
    case clientConnectionError
}

public class SocketManager {
    
    var serverSocketAdd: sockaddr_in
    public private(set) var socketFD: CInt?
    var bindResult: CInt?
    var serverBacklogNumber: CInt = 1024
    var listenResult: CInt?
    var clientSocketAdd: sockaddr_in?
    public private(set) var serverAcceptFD: CInt?
    public private(set) var sockAddrPtr: UnsafeMutablePointer<sockaddr>?
    public private(set) var clientIPAddr: String?
    var clientConnectionStatus: CInt?

    public init(isForServer: Bool = true, serverIP: NSString, port: UInt16) {
        let serverIPInCString = serverIP.cString(using: String.Encoding.ascii.rawValue)!
        serverSocketAdd = sockaddr_in(sin_len: __uint8_t(Const.sockaddr_inSize),
                                      sin_family: sa_family_t(AF_INET),
                                      sin_port: port.bigEndian,
                                      sin_addr: in_addr(s_addr: isForServer ? INADDR_ANY : inet_addr(serverIPInCString)),
                                      sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        guard isForServer else {
            return
        }
        clientSocketAdd = sockaddr_in(sin_len: 0,
                                      sin_family: sa_family_t(0),
                                      sin_port: 0,
                                      sin_addr: in_addr(s_addr: INADDR_ANY),
                                      sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    }
    
    public func createSocket() throws {
        socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard let fd = socketFD, fd >= 0 else {
            throw SocketError.SocketCreationError
        }
    }
    
    //MARK: - SERVER
    public func bind() throws {
        try withUnsafePointer(to: &serverSocketAdd) { [weak self] pointer in
            guard let self = self else { return }
            //swift way to cast C Pointer
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { castedPointer in
                self.bindResult = Darwin.bind(self.socketFD!, castedPointer, Const.sockaddr_inSize)
                guard let bindResult = self.bindResult, bindResult >= 0 else {
                    throw SocketError.BindError
                }
            }
        }
    }
    
    public func listen() throws {
        listenResult = Darwin.listen(socketFD!, serverBacklogNumber)
        guard let result = listenResult, result >= 0 else {
           throw SocketError.ListenError
        }
    }

    public func accept() throws {
        try withUnsafePointer(to: &clientSocketAdd) { [weak self] pointer in
            guard let self = self else { return }
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { castedPointer in
                self.sockAddrPtr = UnsafeMutablePointer<sockaddr>(mutating: castedPointer)
                self.serverAcceptFD = Darwin.accept(self.socketFD!, self.sockAddrPtr, &Const.sockaddr_inSize)
                guard let acceptFD = self.serverAcceptFD, acceptFD >= 0 else {
                    throw SocketError.AcceptError
                }
            }
        }
    }
    
    public func getClientIpAddr() {
        self.sockAddrPtr?.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { [weak self] pointer in
            guard let self = self else { return }
            let clientAddrCStr = UnsafeMutablePointer<CChar>.allocate(capacity: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &pointer.pointee.sin_addr, clientAddrCStr, socklen_t(INET_ADDRSTRLEN))
            self.clientIPAddr = String(cString: clientAddrCStr)
        }
    }

    //MARK: - Client
    public func connect() throws {
        try withUnsafePointer(to: &serverSocketAdd) { [weak self] pointer in
           guard let self = self else { return }
           try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { castedPointer in
                self.clientConnectionStatus = Darwin.connect(socketFD!, castedPointer, Const.sockaddr_inSize)
                guard let statusCode = self.clientConnectionStatus, statusCode >= 0 else {
                    throw SocketError.clientConnectionError
                }
            }
        }
    }

}
