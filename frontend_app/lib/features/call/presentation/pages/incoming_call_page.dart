import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/services/signaling_service.dart';
import '../../domain/repositories/call_repository.dart';
import '../bloc/incoming_call/incoming_call_bloc.dart';
import '../bloc/incoming_call/incoming_call_state.dart';
import '../bloc/incoming_call/incoming_call_event.dart';
import 'call_screen_page.dart';

/// Incoming call screen: shows caller name, Accept and Decline.
/// Uses [IncomingCallBloc] for state. On Accept: bloc gets token, then we navigate to [CallScreenPage].
class IncomingCallPage extends StatefulWidget {
  const IncomingCallPage({
    super.key,
    required this.callId,
    required this.callerName,
    this.channelName,
    this.callerId,
  });

  final String callId;
  final String callerName;
  final String? channelName;
  final String? callerId;

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  StreamSubscription<CallEndedPayload>? _cancelledSub;
  static const Duration _responseDisplayDuration = Duration(seconds: 2);

  void _startRingtone() {
    try {
      FlutterRingtonePlayer().playRingtone();
    } catch (_) {}
  }

  void _stopRingtone() {
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _startRingtone();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cancelledSub != null) return;
    try {
      final signaling = context.read<SignalingService>();
      _cancelledSub = signaling.callCancelled.listen((payload) {
        if (payload.callId != widget.callId) return;
        if (mounted) {
          _stopRingtone();
          context.read<IncomingCallBloc>().add(const IncomingCallCancelled());
        }
      });
    } catch (_) {}
  }

  void _popAfterDelay() {
    Future.delayed(_responseDisplayDuration, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _stopRingtone();
    _cancelledSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<IncomingCallBloc>(
      create: (_) => IncomingCallBloc(
        callId: widget.callId,
        callRepository: context.read<CallRepository>(),
      ),
      child: _IncomingCallView(
        callerName: widget.callerName,
        popAfterDelay: _popAfterDelay,
        onAcceptTap: _stopRingtone,
        onDeclineTap: _stopRingtone,
      ),
    );
  }
}

class _IncomingCallView extends StatelessWidget {
  const _IncomingCallView({
    required this.callerName,
    required this.popAfterDelay,
    this.onAcceptTap,
    this.onDeclineTap,
  });

  final String callerName;
  final VoidCallback popAfterDelay;
  final VoidCallback? onAcceptTap;
  final VoidCallback? onDeclineTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return BlocListener<IncomingCallBloc, IncomingCallState>(
      listenWhen: (prev, state) =>
          state is IncomingCallAccepted ||
          state is IncomingCallDeclined ||
          state is IncomingCallEndedByCaller ||
          state is IncomingCallError,
      listener: (context, state) {
        if (state is IncomingCallAccepted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => CallScreenPage(token: state.token),
            ),
            (route) => route.isFirst,
          );
        } else if (state is IncomingCallDeclined) {
          Navigator.of(context).pop();
        } else if (state is IncomingCallEndedByCaller ||
            state is IncomingCallError) {
          popAfterDelay();
        }
      },
      child: BlocBuilder<IncomingCallBloc, IncomingCallState>(
        builder: (context, state) {
          final loading = state is IncomingCallLoading;
          final endedMessage = state is IncomingCallEndedByCaller
              ? 'Call cancelled'
              : null;
          final error = state is IncomingCallError ? state.message : null;
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
                onPressed: loading
                    ? null
                    : () => context.read<IncomingCallBloc>().add(
                        const IncomingCallDeclineRequested(),
                      ),
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (endedMessage != null)
                      _ResponseMessage(message: endedMessage, isError: false)
                    else if (error != null)
                      _ResponseMessage(
                        message: 'Call failed',
                        subtitle: error,
                        isError: true,
                      )
                    else ...[
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
                        'Incoming call',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        callerName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.grey.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const Spacer(),
                    if (endedMessage == null && error == null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ActionButton(
                            icon: Icons.call_end_rounded,
                            label: 'Decline',
                            color: Colors.red.shade600,
                            onPressed: loading
                                ? null
                                : () {
                                    onDeclineTap?.call();
                                    context.read<IncomingCallBloc>().add(
                                      const IncomingCallDeclineRequested(),
                                    );
                                  },
                          ),
                          _ActionButton(
                            icon: Icons.call_rounded,
                            label: 'Accept',
                            color: colorScheme.primary,
                            onPressed: loading
                                ? null
                                : () {
                                    onAcceptTap?.call();
                                    context.read<IncomingCallBloc>().add(
                                      const IncomingCallAcceptRequested(),
                                    );
                                  },
                          ),
                        ],
                      ),
                    if (endedMessage != null || error != null)
                      const SizedBox(height: 32),
                    if (loading)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Center(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: AppLoading.strokeWidth,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
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
          elevation: 2,
          shadowColor: Colors.black26,
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
