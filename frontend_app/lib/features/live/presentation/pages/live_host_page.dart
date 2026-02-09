import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../call/data/services/agora_rtc_service.dart';
import '../../domain/entities/start_live_entity.dart';
import '../../domain/repositories/live_repository.dart';
import '../bloc/live_host/live_host_bloc.dart';
import '../bloc/live_host/live_host_event.dart';
import '../bloc/live_host/live_host_state.dart';

/// Host screen: user is live (Agora publisher). Uses [LiveHostBloc].
class LiveHostPage extends StatefulWidget {
  const LiveHostPage({super.key, required this.startData});

  final StartLiveEntity startData;

  @override
  State<LiveHostPage> createState() => _LiveHostPageState();
}

class _LiveHostPageState extends State<LiveHostPage>
    with WidgetsBindingObserver {
  late final AgoraRtcService _agora;
  late final LiveHostBloc _bloc;
  bool _mutedByLifecycle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _agora = AgoraRtcService();
    _bloc = LiveHostBloc(
      agora: _agora,
      liveRepository: context.read<LiveRepository>(),
    )..add(LiveHostJoinRequested(widget.startData));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_bloc.state is LiveHostLive && _bloc.isInChannel && !_bloc.isMuted) {
        _bloc.toggleMute();
        _mutedByLifecycle = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_mutedByLifecycle && _bloc.isMuted) {
        _bloc.toggleMute();
        _mutedByLifecycle = false;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return BlocProvider<LiveHostBloc>.value(
      value: _bloc,
      child: BlocListener<LiveHostBloc, LiveHostState>(
        listenWhen: (prev, state) =>
            state is LiveHostEnded || state is LiveHostError,
        listener: (context, state) {
          if (!context.mounted) return;
          if (state is LiveHostEnded) {
            Navigator.of(context).pop();
          } else if (state is LiveHostError) {
            // Pop back to hub and propagate error message so it can be shown there.
            Navigator.of(context).pop(state.message);
          }
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            // Don't leave while joining — avoids accidental back closing the screen.
            final bloc = context.read<LiveHostBloc>();
            if (bloc.state is LiveHostJoining) return;
            bloc.add(const LiveHostLeaveRequested());
          },
          child: BlocBuilder<LiveHostBloc, LiveHostState>(
            builder: (context, state) {
              final joining = state is LiveHostJoining;
              final error = state is LiveHostError ? state.message : null;
              final live = state is LiveHostLive;
              return Scaffold(
                backgroundColor: Colors.grey.shade50,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: joining
                        ? null
                        : () => context.read<LiveHostBloc>().add(
                              const LiveHostLeaveRequested(),
                            ),
                  ),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Live',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!joining && error == null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.mic_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                      ],
                    ],
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (error != null) ...[
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              error,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.red.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final repo = context.read<LiveRepository>();
                                final newData = await repo.getHostToken();
                                if (newData != null && context.mounted) {
                                  context.read<LiveHostBloc>().add(
                                    LiveHostJoinRequested(newData),
                                  );
                                }
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              label: const Text('Retry with new token'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ]
                        else if (joining)
                          AppLoading.withLabel(
                            context,
                            label: 'Starting your stream…',
                          )
                        else if (live) ...[
                          Icon(
                            Icons.mic_rounded,
                            size: 64,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "You're live",
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.grey.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Listeners can tune in from the dashboard.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const Spacer(),
                        if (!joining && error == null && live)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => context.read<LiveHostBloc>().add(
                                const LiveHostEndRequested(),
                              ),
                              icon: const Icon(Icons.stop_rounded, size: 22),
                              label: const Text('End live'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
