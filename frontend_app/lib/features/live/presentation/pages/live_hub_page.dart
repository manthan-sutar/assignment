import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../call/data/services/signaling_service.dart';
import '../../domain/entities/live_session_entity.dart';
import '../bloc/live_hub/live_hub_bloc.dart';
import '../bloc/live_hub/live_hub_event.dart';
import '../bloc/live_hub/live_hub_state.dart';
import 'live_host_page.dart';
import 'live_listener_page.dart';

/// Hub: "Go live" button and real-time "Live now" list. Uses [LiveHubBloc].
class LiveHubPage extends StatefulWidget {
  const LiveHubPage({super.key});

  @override
  State<LiveHubPage> createState() => _LiveHubPageState();
}

class _LiveHubPageState extends State<LiveHubPage> {
  StreamSubscription<dynamic>? _startedSub;
  StreamSubscription<dynamic>? _endedSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedSub != null) return;
    try {
      final signaling = context.read<SignalingService>();
      final bloc = context.read<LiveHubBloc>();
      _startedSub = signaling.liveStarted.listen((payload) {
        if (!mounted) return;
        bloc.add(
          LiveHubSessionStarted(
            LiveSessionEntity(
              sessionId: payload.sessionId,
              channelName: payload.channelName,
              hostUserId: payload.hostUserId,
              hostDisplayName: payload.hostDisplayName,
              startedAt: payload.startedAt,
            ),
          ),
        );
      });
      _endedSub = signaling.liveEnded.listen((payload) {
        if (!mounted) return;
        bloc.add(LiveHubSessionEnded(payload.sessionId));
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _startedSub?.cancel();
    _endedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = context.watch<AuthBloc>().state;
    final currentUid = authState is AuthAuthenticated
        ? authState.user.firebaseUid
        : null;

    return BlocListener<LiveHubBloc, LiveHubState>(
      listenWhen: (prev, state) => state is LiveHubStartSuccess,
      listener: (context, state) {
        if (state is LiveHubStartSuccess) {
          Navigator.of(context)
              .push(
                MaterialPageRoute<void>(
                  builder: (_) => LiveHostPage(startData: state.startData),
                ),
              )
              .then((_) {
                if (mounted)
                  context.read<LiveHubBloc>().add(const LiveHubLoadSessions());
              });
        }
      },
      child: BlocBuilder<LiveHubBloc, LiveHubState>(
        builder: (context, state) {
          final sessions = state is LiveHubLoaded
              ? state.sessions
              : <LiveSessionEntity>[];
          final loading = state is LiveHubLoading;
          final endingLive = state is LiveHubLoaded && state.endingLive;
          final error = state is LiveHubError ? state.message : null;
          final mySession = currentUid != null
              ? sessions.where((s) => s.hostUserId == currentUid).firstOrNull
              : null;
          final otherSessions = currentUid != null
              ? sessions.where((s) => s.hostUserId != currentUid).toList()
              : sessions;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Audio Streaming'),
              centerTitle: true,
            ),
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  context.read<LiveHubBloc>().add(const LiveHubLoadSessions());
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: loading || mySession != null
                            ? null
                            : () => context.read<LiveHubBloc>().add(
                                const LiveHubGoLive(),
                              ),
                        icon: const Icon(Icons.mic_rounded, size: 24),
                        label: Text(
                          mySession != null ? "You're live" : 'Go live',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (mySession != null) ...[
                        const SizedBox(height: 12),
                        Material(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.mic_rounded,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "You're live. End your stream to go live again.",
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: (loading || endingLive)
                                      ? null
                                      : () => context.read<LiveHubBloc>().add(
                                          const LiveHubEndMyLive(),
                                        ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    endingLive ? 'Ending…' : 'End live',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (error != null && mySession == null) ...[
                        const SizedBox(height: 16),
                        Text(
                          error,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'Live now',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (loading && sessions.isEmpty)
                        AppLoading.section(context)
                      else if (otherSessions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              mySession != null
                                  ? 'No one else is live right now.'
                                  : 'No one is live right now.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        )
                      else
                        ...otherSessions.map(
                          (session) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _LiveSessionCard(
                              session: session,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        LiveListenerPage(session: session),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
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

class _LiveSessionCard extends StatelessWidget {
  const _LiveSessionCard({required this.session, required this.onTap});

  final LiveSessionEntity session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = session.hostDisplayName.isNotEmpty
        ? session.hostDisplayName.substring(0, 1).toUpperCase()
        : '?';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.deepPurple.shade50,
                child: Text(
                  initial,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.hostDisplayName.isEmpty
                          ? 'Host'
                          : session.hostDisplayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Live',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.headphones_rounded, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
