import Testing
@testable import Fullball

struct LinkPromptPolicyTests {
    @Test func promptsOnlyWhenAnonUnpromptedAndMilestoneReached() {
        #expect(LinkPromptPolicy.shouldPrompt(isAnonymous: true, alreadyPrompted: false, firstMilestoneReached: true))
        // negatives
        #expect(!LinkPromptPolicy.shouldPrompt(isAnonymous: false, alreadyPrompted: false, firstMilestoneReached: true))
        #expect(!LinkPromptPolicy.shouldPrompt(isAnonymous: true, alreadyPrompted: true, firstMilestoneReached: true))
        #expect(!LinkPromptPolicy.shouldPrompt(isAnonymous: true, alreadyPrompted: false, firstMilestoneReached: false))
    }
}
