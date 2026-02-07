import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/services/signaling_service.dart';
import '../bloc/ringing/ringing_bloc.dart';
import '../bloc/ringing/ringing_state.dart';
import '../bloc/ringing/ringing_event.dart';
import 'call_screen_page.dart';

/// Caller-side "Ringing" screen: create offer, show "Calling X...", listen for accept/decline/cancel.
/// Uses [RingingBloc] for state; signaling subscriptions dispatch events to the bloc.
class CallRingingPage extends StatefulWidget {
  const CallRingingPage({super.key, required this.calleeDisplayName});

  final String calleeDisplayName;

  @override
  State<CallRingingPage> createState() => _CallRingingPageState();
}

class _CallRingingPageState extends State<CallRingingPage> {
  StreamSubscription<CallAcceptedPayload>? _acceptedSub;
  StreamSubscription<CallEndedPayload>? _declinedSub;
  StreamSubscription<CallEndedPayload>? _cancelledSub;
  Timer? _ringingTimeout;
  static const Duration _ringingTimeoutDuration = Duration(seconds: 60);
  static const Duration _responseDisplayDuration = Duration(seconds: 2);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_acceptedSub != null) return;
    _listenToSignaling();
  }

  void _listenToSignaling() {
    final bloc = context.read<RingingBloc>();
    final signaling = context.read<SignalingService>();
    _acceptedSub = signaling.callAccepted.listen((payload) {
      final state = bloc.state;
      if (state is! RingingWaiting || state.callId != payload.callId) return;
      bloc.add(RingingCallAccepted(payload.channelName));
    });
    _declinedSub = signaling.callDeclined.listen((payload) {
      final state = bloc.state;
      if (state is! RingingWaiting || state.callId != payload.callId) return;
      _ringingTimeout?.cancel();
      bloc.add(const RingingCallDeclined());
    });
    _cancelledSub = signaling.callCancelled.listen((payload) {
      final state = bloc.state;
      if (state is! RingingWaiting || state.callId != payload.callId) return;
      _ringingTimeout?.cancel();
      bloc.add(const RingingCallCancelled());
    });
  }

  void _startRingingTimeout(String callId) {
    _ringingTimeout?.cancel();
    _ringingTimeout = Timer(_ringingTimeoutDuration, () async {
      if (!mounted) return;
      final bloc = context.read<RingingBloc>();
      if (bloc.state is! RingingWaiting) return;
      await bloc.cancelCall(callId);
      if (mounted) bloc.add(const RingingTimeout());
      _ringingTimeout?.cancel();
    });
  }

  void _popAfterDelay() {
    Future.delayed(_responseDisplayDuration, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _cancel() async {
    final state = context.read<RingingBloc>().state;
    if (state is RingingWaiting) {
      await context.read<RingingBloc>().cancelCall(state.callId);
    }
    _ringingTimeout?.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ringingTimeout?.cancel();
    _acceptedSub?.cancel();
    _declinedSub?.cancel();
    _cancelledSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return BlocConsumer<RingingBloc, RingingState>(
      listenWhen: (prev, state) =>
          state is RingingAccepted ||
          state is RingingEnded ||
          state is RingingError,
      listener: (context, state) {
        if (state is RingingAccepted) {
          _ringingTimeout?.cancel();
          _acceptedSub?.cancel();
          _declinedSub?.cancel();
          _cancelledSub?.cancel();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => CallScreenPage(token: state.token),
            ),
            (route) => route.isFirst,
          );
        } else if (state is RingingEnded || state is RingingError) {
          _popAfterDelay();
        }
      },
      buildWhen: (prev, state) => true,
      builder: (context, state) {
        if (state is RingingWaiting &&
            (_ringingTimeout == null || !_ringingTimeout!.isActive)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _startRingingTimeout(state.callId);
          });
        }
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.grey.shade800,
              ),
              onPressed: _cancel,
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (state is RingingCreating)
                    AppLoading.withLabel(
                      context,
                      label: 'Connecting…',
                      padding: const EdgeInsets.symmetric(vertical: 48),
                    )
                  else if (state is RingingError)
                    _ResponseMessage(
                      message: 'Call failed',
                      subtitle: state.message,
                      isError: true,
                    )
                  else if (state is RingingEnded)
                    _ResponseMessage(
                      message: state.status == 'declined'
                          ? 'Declined'
                          : state.status == 'timeout'
                          ? 'No answer'
                          : 'Call cancelled',
                      isError: false,
                    )
                  else if (state is RingingWaiting) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.call_rounded,
                        size: 56,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Calling…',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.calleeDisplayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.grey.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const Spacer(),
                  if (state is RingingWaiting)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CallActionButton(
                          icon: Icons.call_end_rounded,
                          label: 'Cancel',
                          color: Colors.red.shade600,
                          onPressed: _cancel,
                        ),
                        _CallActionButton(
                          icon: Icons.schedule_rounded,
                          label: 'Waiting…',
                          color: Colors.grey.shade400,
                          onPressed: null,
                        ),
                      ],
                    )
                  else
                    const SizedBox(height: 32),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          elevation: onPressed != null ? 2 : 0,
          shadowColor: onPressed != null ? Colors.black26 : null,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ResponseMessage extends StatelessWidget {
  const _ResponseMessage({
    required this.message,
    this.subtitle,
    required this.isError,
  });

  final String message;
  final String? subtitle;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError ? Colors.red.shade700 : Colors.grey.shade700;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
