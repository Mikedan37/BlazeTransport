/// Simple state machine with State/Event/Effect pattern.
import Foundation

/// Simple state machine implementation matching the expected API.
struct StateMachine<State: Equatable, Event: Equatable, Effect> {
    private var currentState: State
    private var transitions: [(from: State, on: Event, to: State, effects: [Effect])] = []
    
    init(initialState: State) {
        self.currentState = initialState
    }
    
    mutating func addTransition(from: State, on: Event, to: State, effects: [Effect]) {
        transitions.append((from: from, on: on, to: to, effects: effects))
    }
    
    mutating func process(_ event: Event) -> [Effect] {
        for transition in transitions {
            if transition.from == currentState && transition.on == event {
                currentState = transition.to
                return transition.effects
            }
        }
        return []
    }
    
    var state: State {
        currentState
    }
}

