import Foundation
import ServiceLifecycle
import Logging
import MCP
import NIO
import NIOFoundationCompat

/// Service that listens for commands from Claude Desktop via a local socket
actor CommandReceiverService: Service {
    private let port: Int
    private let server: Server
    private let logger: Logger
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private var channel: Channel?
    
    init(port: Int, server: Server, logger: Logger) {
        self.port = port
        self.server = server
        self.logger = logger
    }
    
    func run() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.eventLoopGroup = eventLoopGroup
        
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.addHandlers([
                    ByteToMessageHandler(LineBasedFrameDecoder()),
                    MessageToByteHandler(LineEncoder()),
                    CommandHandler(server: self.server, logger: self.logger)
                ])
            }
        
        do {
            let channel = try await bootstrap.bind(host: "127.0.0.1", port: port).get()
            self.channel = channel
            
            logger.info("Command receiver listening on 127.0.0.1:\(port)")
            
            // Keep the service running
            try await channel.closeFuture.get()
        } catch {
            logger.error("Failed to start command receiver: \(error)")
            throw error
        }
    }
    
    func shutdown() async {
        logger.info("Shutting down command receiver")
        
        if let channel = channel {
            try? await channel.close().get()
        }
        
        if let eventLoopGroup = eventLoopGroup {
            try? await eventLoopGroup.shutdownGracefully()
        }
    }
}

// MARK: - Channel Handlers

final class LineBasedFrameDecoder: ByteToMessageDecoder {
    typealias InboundOut = ByteBuffer
    
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        if let newlineIndex = buffer.readableBytesView.firstIndex(of: UInt8(ascii: "\n")) {
            let length = newlineIndex - buffer.readerIndex + 1
            if let line = buffer.readSlice(length: length) {
                context.fireChannelRead(wrapInboundOut(line))
                return .continue
            }
        }
        return .needMoreData
    }
}

final class LineEncoder: MessageToByteEncoder {
    typealias OutboundIn = String
    
    func encode(data: String, out: inout ByteBuffer) throws {
        out.writeString(data)
        if !data.hasSuffix("\n") {
            out.writeString("\n")
        }
    }
}

final class CommandHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = String
    
    private let server: Server
    private let logger: Logger
    
    init(server: Server, logger: Logger) {
        self.server = server
        self.logger = logger
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        
        guard let string = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) else {
            return
        }
        
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.debug("Received command request: \(trimmed)")
        
        // Handle the command
        handleCommand(trimmed: trimmed, context: context)
    }
    
    private func handleCommand(trimmed: String, context: ChannelHandlerContext) {
        do {
            guard let data = trimmed.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else {
                sendResponse(context: context, response: ["error": "Invalid JSON or missing type"])
                return
            }
            
            // Process command based on type
            // For now, send mock responses synchronously
            let response: [String: Any]
            
            switch type {
            case "suggest":
                if let query = json["query"] as? String {
                    response = [
                        "status": "success",
                        "suggestion": "echo 'Hello from Claude Command Runner'",
                        "explanation": "This is a test command suggestion for: \(query)"
                    ]
                } else {
                    response = ["error": "Missing query parameter"]
                }
                
            case "execute":
                if let command = json["command"] as? String {
                    // For safety, we'll just echo the command for now
                    response = [
                        "status": "success",
                        "output": "Would execute: \(command)",
                        "exitCode": 0
                    ]
                } else {
                    response = ["error": "Missing command parameter"]
                }
                
            case "ping":
                response = ["status": "pong"]
                
            default:
                response = ["error": "Unknown command type: \(type)"]
            }
            
            sendResponse(context: context, response: response)
            
        } catch {
            logger.error("Error processing command: \(error)")
            sendResponse(context: context, response: ["error": error.localizedDescription])
        }
    }
    
    private func sendResponse(context: ChannelHandlerContext, response: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: response, options: [])
            if let string = String(data: data, encoding: .utf8) {
                context.writeAndFlush(self.wrapOutboundOut(string), promise: nil)
            }
        } catch {
            logger.error("Failed to send response: \(error)")
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: any Swift.Error) {
        logger.error("Channel error: \(error)")
        context.close(promise: nil)
    }
}

// MARK: - MCPService wrapper

struct MCPService: Service {
    let server: Server
    let transport: any Transport
    
    func run() async throws {
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
    
    func shutdown() async {
        await server.stop()
    }
}
