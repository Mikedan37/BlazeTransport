/// Platform-specific socket selection.
/// Provides the appropriate DatagramSocket implementation for the current platform.
#if canImport(Darwin)
import Foundation
typealias PlatformDatagramSocket = DarwinDatagramSocket
#elseif canImport(Glibc)
import Foundation
typealias PlatformDatagramSocket = LinuxDatagramSocket
#else
#error("Unsupported platform: BlazeTransport requires Darwin or Glibc")
#endif

