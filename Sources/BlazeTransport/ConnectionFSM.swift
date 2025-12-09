/// Connection-level state machine using BlazeFSM.
/// Manages connection lifecycle: idle → synSent → handshake → active → draining → closed.
import Foundation
import BlazeFSM

/// Connection-level state machine states.
enum ConnectionState: Equatable {
    case idle
    case synSent
    case handshake
    case active
    case draining
    case closed
}

/// Connection-level events.
/// Note: Events with associated values are matched by case, not by value equality.
enum ConnectionEvent: Equatable {
    case appOpenRequested
    case packetReceived
    case handshakeSucceeded
    case handshakeFailed
    case appCloseRequested
    case timeout(String)
    
    /// Helper to create packetReceived event (matched by case only).
    static func packetReceived(_ packet: BlazePacket) -> ConnectionEvent {
        .packetReceived
    }
    
    /// Helper to create handshakeFailed event (matched by case only).
    static func handshakeFailed(_ error: Error) -> ConnectionEvent {
        .handshakeFailed
    }
}

enum ConnectionEffect {
    case sendPacket(BlazePacket)
    case startTimer(String, TimeInterval)
    case cancelTimer(String)
    case markHandshakeStarted
    case markActive
    case markClosed
}

typealias ConnectionStateMachine = StateMachine<ConnectionState, ConnectionEvent, ConnectionEffect>

func makeConnectionStateMachine() -> ConnectionStateMachine {
    var machine = StateMachine<ConnectionState, ConnectionEvent, ConnectionEffect>(
        initialState: .idle
    )

    // idle + appOpenRequested -> synSent, [sendPacket(handshake), startTimer]
    machine.addTransition(
        from: .idle,
        on: .appOpenRequested,
        to: .synSent,
        effects: [
            .sendPacket(BlazePacket(
                header: BlazePacketHeader(
                    version: 1,
                    flags: 0,
                    connectionID: 0,
                    packetNumber: 0,
                    streamID: 0,
                    payloadLength: 0
                ),
                payload: Data()
            )),
            .startTimer("handshake", 5.0),
            .markHandshakeStarted
        ]
    )

    // synSent + packetReceived -> handshake, [sendPacket(handshake-ack)]
    // Note: Packet details are handled in ConnectionManager, event is matched by case
    machine.addTransition(
        from: .synSent,
        on: .packetReceived,
        to: .handshake,
        effects: [
            .sendPacket(BlazePacket(
                header: BlazePacketHeader(
                    version: 1,
                    flags: 0,
                    connectionID: 0,
                    packetNumber: 0,
                    streamID: 0,
                    payloadLength: 0
                ),
                payload: Data()
            ))
        ]
    )

    // handshake + handshakeSucceeded -> active, [markActive, cancelTimer]
    machine.addTransition(
        from: .handshake,
        on: .handshakeSucceeded,
        to: .active,
        effects: [
            .cancelTimer("handshake"),
            .markActive
        ]
    )

    // handshake + handshakeFailed -> closed, [markClosed]
    // Note: Error details are handled in ConnectionManager, event is matched by case
    machine.addTransition(
        from: .handshake,
        on: .handshakeFailed,
        to: .closed,
        effects: [.markClosed]
    )

    // active + appCloseRequested -> draining, [sendPacket(close)]
    machine.addTransition(
        from: .active,
        on: .appCloseRequested,
        to: .draining,
        effects: [
            .sendPacket(BlazePacket(
                header: BlazePacketHeader(
                    version: 1,
                    flags: 0,
                    connectionID: 0,
                    packetNumber: 0,
                    streamID: 0,
                    payloadLength: 0
                ),
                payload: Data()
            ))
        ]
    )

    // draining + timeout -> closed, [markClosed]
    machine.addTransition(
        from: .draining,
        on: .timeout("drain"),
        to: .closed,
        effects: [.markClosed]
    )

    // synSent + timeout(handshake) -> closed, [markClosed]
    machine.addTransition(
        from: .synSent,
        on: .timeout("handshake"),
        to: .closed,
        effects: [.markClosed]
    )

    return machine
}

