/// Stream manager and per-stream state machines using BlazeFSM.
/// Manages multiple concurrent streams, each with its own lifecycle state machine.
import Foundation
import BlazeFSM

/// Stream-level state machine states.
enum StreamState: Equatable {
    case idle
    case open
    case halfClosedLocal
    case halfClosedRemote
    case closed
}

/// Stream-level events.
/// Note: Events with associated values are matched by case, not by value equality.
enum StreamEvent: Equatable {
    case appSend
    case frameReceived
    case appClose
    case resetReceived
    
    /// Helper to create appSend event (matched by case only).
    static func appSend(_ data: Data) -> StreamEvent {
        .appSend
    }
    
    /// Helper to create frameReceived event (matched by case only).
    static func frameReceived(_ data: Data) -> StreamEvent {
        .frameReceived
    }
}

enum StreamEffect {
    case emitFrame(Data)        // frame to send on wire
    case deliverToApp(Data)     // data to deliver to DefaultBlazeStream
    case markClosed
}

typealias StreamStateMachine = StateMachine<StreamState, StreamEvent, StreamEffect>

actor StreamManager {
    private var streams: [UInt32: StreamStateMachine] = [:]
    private var nextStreamID: UInt32 = 1

    func openStream() async -> UInt32 {
        let streamID = nextStreamID
        nextStreamID += 1

        let machine = makeStreamStateMachine()
        streams[streamID] = machine

        return streamID
    }

    func handleAppSend(on streamID: UInt32, data: Data) async -> [StreamEffect] {
        guard var machine = streams[streamID] else {
            return []
        }

        let effects = machine.process(.appSend)
        streams[streamID] = machine

        // Replace placeholder effects with actual data
        return effects.map { effect in
            switch effect {
            case .emitFrame:
                return .emitFrame(data)
            case .deliverToApp, .markClosed:
                return effect
            }
        }
    }

    func handleFrameReceived(streamID: UInt32, data: Data) async -> [StreamEffect] {
        guard var machine = streams[streamID] else {
            return []
        }

        let effects = machine.process(.frameReceived)
        streams[streamID] = machine

        // Replace placeholder effects with actual data
        return effects.map { effect in
            switch effect {
            case .deliverToApp:
                return .deliverToApp(data)
            case .emitFrame, .markClosed:
                return effect
            }
        }
    }

    func closeStream(_ streamID: UInt32) async {
        streams.removeValue(forKey: streamID)
    }
}

func makeStreamStateMachine() -> StreamStateMachine {
    var machine = StateMachine<StreamState, StreamEvent, StreamEffect>(
        initialState: .idle
    )

    // idle + appSend -> open, emitFrame(data)
    // Note: Data details are handled in StreamManager, event is matched by case
    machine.addTransition(
        from: .idle,
        on: .appSend,
        to: .open,
        effects: [.emitFrame(Data())]
    )

    // open + frameReceived -> open, deliverToApp(data)
    // Note: Data details are handled in StreamManager, event is matched by case
    machine.addTransition(
        from: .open,
        on: .frameReceived,
        to: .open,
        effects: [.deliverToApp(Data())]
    )

    // open + appClose -> halfClosedLocal, emitFrame(close-marker)
    machine.addTransition(
        from: .open,
        on: .appClose,
        to: .halfClosedLocal,
        effects: [.emitFrame(Data())]
    )

    // open + resetReceived -> closed, markClosed
    machine.addTransition(
        from: .open,
        on: .resetReceived,
        to: .closed,
        effects: [.markClosed]
    )

    // halfClosedLocal + frameReceived -> closed, markClosed
    // Note: Data details are handled in StreamManager, event is matched by case
    machine.addTransition(
        from: .halfClosedLocal,
        on: .frameReceived,
        to: .closed,
        effects: [.markClosed]
    )

    return machine
}

