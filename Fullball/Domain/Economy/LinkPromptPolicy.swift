import Foundation

/// Pure decision for the one-time "Link Apple ID" soft prompt: show it only when
/// the player is still anonymous, hasn't been prompted before, and has just hit
/// their first milestone (the chosen hook moment).
enum LinkPromptPolicy {
    static func shouldPrompt(isAnonymous: Bool,
                             alreadyPrompted: Bool,
                             firstMilestoneReached: Bool) -> Bool {
        isAnonymous && !alreadyPrompted && firstMilestoneReached
    }
}
