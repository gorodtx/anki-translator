import Testing
@testable import TranslatorCore

@Suite struct ReplyOrderingTests {
    /// Nothing of the request has arrived yet: the reply is the first state it has.
    @Test func aReplyAheadOfItsEventsApplies() {
        #expect(ReplyOrdering.replyApplies(request: 7, active: 5, lastEvent: 5))
    }

    /// Its "begin" (or, cached, its "final") came first: the reply must not put it back.
    @Test func aReplyBehindItsOwnEventDoesNotApply() {
        #expect(!ReplyOrdering.replyApplies(request: 7, active: 7, lastEvent: 7))
    }

    /// A newer lookup started while this one waited: it owns the state.
    @Test func aReplyToAnOlderRequestNeverApplies() {
        #expect(!ReplyOrdering.replyApplies(request: 7, active: 9, lastEvent: 5))
        #expect(!ReplyOrdering.replyApplies(request: 7, active: 9, lastEvent: 9))
    }
}
