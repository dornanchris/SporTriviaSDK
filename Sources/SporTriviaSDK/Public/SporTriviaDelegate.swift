import Foundation

/// Delegate protocol for receiving game lifecycle events from the SDK.
public protocol SporTriviaDelegate: AnyObject {
    /// Called when the player completes the game (all answers found or gave up).
    func sporTriviaDidComplete(result: SporTriviaGameResult)

    /// Called when the player cancels/dismisses the game flow.
    func sporTriviaDidCancel()

    /// Called when the SDK encounters an unrecoverable error.
    func sporTriviaDidFail(error: Error)
}
