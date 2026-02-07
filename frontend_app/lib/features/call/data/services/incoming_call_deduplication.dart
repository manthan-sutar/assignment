/// Ensures we never show the incoming call UI twice for the same [callId],
/// and never stack multiple incoming call screens (e.g. after missed calls).
class IncomingCallDeduplication {
  IncomingCallDeduplication._();

  static final Set<String> _shownCallIds = {};
  static bool _incomingCallUIVisible = false;

  /// True if an incoming call screen is already on the stack. When true, do not push another.
  static bool get isIncomingCallUIVisible => _incomingCallUIVisible;

  static void setIncomingCallUIVisible(bool value) {
    _incomingCallUIVisible = value;
  }

  /// Returns true only the first time for this [callId]; then false so caller can skip showing UI.
  static bool shouldShow(String callId) {
    if (callId.isEmpty) return false;
    if (_shownCallIds.contains(callId)) return false;
    _shownCallIds.add(callId);
    return true;
  }
}
