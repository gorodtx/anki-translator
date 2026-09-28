/// Whether the reply to a request may set the view state.
///
/// The backend sends a request's `translation.state` events as it works — the "begin"
/// before it replies, and for a cached result even the "final" — and the client can apply
/// them before the reply resumes its caller. A reply's snapshot is never newer than an
/// event of its own request, so it only fills in while none has been applied; put over a
/// later one, it would turn a finished lookup back into "loading" for good. A reply to a
/// request older than the active one never applies: a newer lookup owns the state.
public enum ReplyOrdering {
    public static func replyApplies(request: Int, active: Int, lastEvent: Int) -> Bool {
        request >= active && lastEvent < request
    }
}
