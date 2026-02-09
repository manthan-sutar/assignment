import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/services/agora_rtc_service.dart';
import '../../domain/entities/call_token_entity.dart';
import '../bloc/active_call/active_call_bloc.dart';
import '../bloc/active_call/active_call_state.dart';
import '../bloc/active_call/active_call_event.dart';

/// Full-screen call UI: join Agora channel with [token], show mute and end call.
/// Uses [ActiveCallBloc] for state; Agora is owned by the page and passed to the bloc.
class CallScreenPage extends StatefulWidget {
  const CallScreenPage({super.key, required this.token});

  final CallTokenEntity token;

  @override
  State<CallScreenPage> createState() => _CallScreenPageState();
}

class _CallScreenPageState extends State<CallScreenPage> {
  late final AgoraRtcService _agora;
  late final ActiveCallBloc _bloc;

  @override
  void initState() {
    super.initState();
    _agora = AgoraRtcService();
    _bloc = ActiveCallBloc(agora: _agora)..add(ActiveCallJoin(widget.token));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return BlocProvider<ActiveCallBloc>.value(
      value: _bloc,
      child: BlocListener<ActiveCallBloc, ActiveCallState>(
        listenWhen: (prev, state) => state is ActiveCallEnded,
        listener: (context, state) {
          if (state is ActiveCallEnded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Call ended'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
            Navigator.of(context).pop();
          }
        },
        child: BlocBuilder<ActiveCallBloc, ActiveCallState>(
          builder: (context, state) {
            final joining = state is ActiveCallJoining;
            final error = state is ActiveCallError ? state.message : null;
            final connected = state is ActiveCallConnected;
            final muted = connected ? state.muted : false;
            final remoteCount = connected ? state.remoteUserCount : 0;
            return Scaffold(
              backgroundColor: Colors.grey.shade50,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: Text(
                  'Voice call',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                centerTitle: true,
              ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            error,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (joining)
                        Expanded(
                          child: AppLoading.withLabel(
                            context,
                            label: 'Joining call…',
                          ),
                        )
                      else if (connected) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.5,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            remoteCount > 0
                                ? Icons.call_rounded
                                : Icons.person_rounded,
                            size: 64,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          remoteCount > 0
                              ? 'In call'
                              : 'Waiting for other party…',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.grey.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _CallButton(
                              icon: muted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              label: muted ? 'Unmute' : 'Mute',
                              color: colorScheme.primary,
                              onPressed: () => context
                                  .read<ActiveCallBloc>()
                                  .add(const ActiveCallMuteToggle()),
                            ),
                            _CallButton(
                              icon: Icons.call_end_rounded,
                              label: 'End',
                              color: Colors.red.shade600,
                              onPressed: () => context
                                  .read<ActiveCallBloc>()
                                  .add(const ActiveCallEnd()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

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
