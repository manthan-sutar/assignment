import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../call/data/services/agora_rtc_service.dart';
import '../../../call/data/services/signaling_service.dart';
import '../../../call/domain/repositories/call_repository.dart';
import '../../domain/entities/live_session_entity.dart';
import '../bloc/live_listener/live_listener_bloc.dart';
import '../bloc/live_listener/live_listener_event.dart';
import '../bloc/live_listener/live_listener_state.dart';

/// Listener screen: user joins a live stream as subscriber. Uses [LiveListenerBloc].
class LiveListenerPage extends StatefulWidget {
  const LiveListenerPage({super.key, required this.session});

  final LiveSessionEntity session;

  @override
  State<LiveListenerPage> createState() => _LiveListenerPageState();
}

class _LiveListenerPageState extends State<LiveListenerPage>
    with WidgetsBindingObserver {
  StreamSubscription<LiveEndedPayload>? _liveEndedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_liveEndedSub != null) return;
    try {
      final signaling = context.read<SignalingService>();
      _liveEndedSub = signaling.liveEnded.listen((payload) {
        if (payload.sessionId != widget.session.sessionId) return;
        if (!mounted) return;
        context.read<LiveListenerBloc>().add(const LiveListenerEndedByHost());
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveEndedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = widget.session;
    return BlocProvider<LiveListenerBloc>(
      create: (_) {
        final agora = AgoraRtcService();
        final bloc = LiveListenerBloc(
          agora: agora,
          session: session,
          callRepository: context.read<CallRepository>(),
        )..add(LiveListenerJoinRequested(session));
        return bloc;
      },
      child: BlocConsumer<LiveListenerBloc, LiveListenerState>(
        listenWhen: (prev, state) =>
            state is LiveListenerEnded || state is LiveListenerHostEnded,
        listener: (context, state) {
          if (state is LiveListenerEnded) {
            Navigator.of(context).pop();
          } else if (state is LiveListenerHostEnded) {
            Future<void>.delayed(const Duration(milliseconds: 1800), () {
              if (mounted) Navigator.of(context).pop();
            });
          }
        },
        builder: (context, state) {
            final joining = state is LiveListenerJoining;
            final error = state is LiveListenerError ? state.message : null;
            final connected = state is LiveListenerConnected;
            final endedByHost = state is LiveListenerHostEnded;
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                context
                    .read<LiveListenerBloc>()
                    .add(const LiveListenerLeaveRequested());
              },
              child: Scaffold(
                backgroundColor: Colors.grey.shade50,
                appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  'Live stream',
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
                      horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (endedByHost)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 56,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Live has ended',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'The host has ended the stream. Taking you back…',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else if (error != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            error,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.red.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else if (joining)
                        AppLoading.withLabel(context, label: 'Connecting…')
                      else if (connected) ...[
                        Icon(
                          Icons.headphones_rounded,
                          size: 64,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Listening to',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          session.hostDisplayName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.grey.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const Spacer(),
                      if (!joining &&
                          error == null &&
                          !endedByHost &&
                          connected)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => context
                                .read<LiveListenerBloc>()
                                .add(const LiveListenerLeaveRequested()),
                            icon: const Icon(Icons.close_rounded, size: 22),
                            label: const Text('Leave'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
