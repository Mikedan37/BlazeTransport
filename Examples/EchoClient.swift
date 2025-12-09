import Foundation
import BlazeTransport

/// Simple echo client that connects to a server and sends/receives messages.
@main
struct EchoClient {
    static func main() async {
        let host = "127.0.0.1"
        let port: UInt16 = 9999
        
        print("Connecting to BlazeTransport server at \(host):\(port)")
        
        do {
            // Connect to server
            let connection = try await BlazeTransport.connect(
                host: host,
                port: port,
                security: .blazeDefault
            )
            
            print("Connected successfully!")
            
            // Open a stream
            let stream = try await connection.openStream()
            print("Stream opened")
            
            // Send a message
            let message = "Hello, BlazeTransport!"
            print("Sending: \(message)")
            try await stream.send(message)
            
            // Receive echo
            let reply: String = try await stream.receive(String.self)
            print("Received: \(reply)")
            
            // Get connection stats
            let stats = await connection.stats()
            print("\nConnection Stats:")
            print("  RTT: \(String(format: "%.3f", stats.roundTripTime))s")
            print("  Congestion Window: \(stats.congestionWindowBytes) bytes")
            print("  Loss Rate: \(String(format: "%.2f", stats.lossRate * 100))%")
            print("  Bytes Sent: \(stats.bytesSent)")
            print("  Bytes Received: \(stats.bytesReceived)")
            
            // Close stream and connection
            try await stream.close()
            try await connection.close()
            
            print("\nConnection closed. Goodbye!")
        } catch {
            print("Error: \(error)")
        }
    }
}

