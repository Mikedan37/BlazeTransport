import Foundation
import BlazeTransport

/// Simple echo client that connects to a server and sends/receives messages.
/// This demonstrates the basic BlazeTransport API usage.
@main
struct EchoClient {
    static func main() async {
        let host = "127.0.0.1"
        let port: UInt16 = 9999
        
        print("BlazeTransport Echo Client")
        print("Connecting to \(host):\(port)")
        print()
        
        do {
            // Connect to server with default security
            let connection = try await BlazeTransport.connect(
                host: host,
                port: port,
                security: .blazeDefault
            )
            
            print("Connected successfully!")
            
            // Open a stream for sending/receiving
            let stream = try await connection.openStream()
            print("Stream opened")
            print()
            
            // Send multiple messages
            let messages = [
                "Hello, BlazeTransport!",
                "This is message 2",
                "And message 3"
            ]
            
            for (index, message) in messages.enumerated() {
                print("Sending message \(index + 1): \(message)")
                try await stream.send(message)
                
                // Receive echo
                let reply: String = try await stream.receive(String.self)
                print("Received echo: \(reply)")
                print()
                
                // Small delay between messages
                try await Task.sleep(for: .milliseconds(100))
            }
            
            // Get and display connection statistics
            let stats = await connection.stats()
            print("Connection Statistics:")
            print("  Round-Trip Time: \(String(format: "%.3f", stats.roundTripTime))s")
            print("  Congestion Window: \(stats.congestionWindowBytes) bytes")
            print("  Loss Rate: \(String(format: "%.2f", stats.lossRate * 100))%")
            print("  Bytes Sent: \(stats.bytesSent)")
            print("  Bytes Received: \(stats.bytesReceived)")
            print()
            
            // Close stream and connection
            try await stream.close()
            print("Stream closed")
            
            try await connection.close()
            print("Connection closed")
            print()
            print("Client finished successfully!")
            
        } catch BlazeTransportError.connectionClosed {
            print("Error: Connection was closed")
        } catch BlazeTransportError.handshakeFailed {
            print("Error: Handshake failed - check server is running")
        } catch BlazeTransportError.timeout {
            print("Error: Operation timed out")
        } catch {
            print("Error: \(error)")
        }
    }
}
