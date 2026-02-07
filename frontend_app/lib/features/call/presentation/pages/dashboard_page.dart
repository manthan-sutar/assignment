import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../features/auth/domain/entities/display_user_entity.dart';
import '../../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../features/live/domain/entities/live_session_entity.dart';
import '../../../../features/live/presentation/bloc/live_hub/live_hub_bloc.dart';
import '../../../../features/live/presentation/bloc/live_hub/live_hub_event.dart';
import '../../../../features/live/presentation/bloc/live_hub/live_hub_state.dart';
import '../../../../features/live/presentation/pages/live_hub_page.dart';
import '../../../../features/live/presentation/pages/live_listener_page.dart';
import '../../../../features/reels/presentation/pages/reels_feed_page.dart';
import '../../data/services/signaling_service.dart';
import 'user_details_page.dart';

/// Dashboard Page
/// Entry to Reels, Find people (from API), and app actions after authentication.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  void _handleLogout(BuildContext context) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout, color: Colors.deepPurple),
            const SizedBox(width: 12),
            Flexible(child: Text('Sign Out', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Dispatch sign out event using the outer context
              context.read<AuthBloc>().add(const SignOutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade600,
              foregroundColor: Colors.white, // White text color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          AppFeedback.showError(context, state.message);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: () => _handleLogout(context),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Welcome',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Listen. Stream. Connect with voice.',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 28),
                const _LiveNowSection(),
                const SizedBox(height: 24),
                Text(
                  'Find people',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<DisplayUserEntity>>(
                  future: context.read<AuthRepository>().getUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return AppLoading.section(context);
                    }
                    final users = snapshot.data ?? [];
                    final displayList = users.take(4).toList();
                    if (displayList.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Users will appear here once available',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        const crossAxisCount = 2;
                        const spacing = 12.0;
                        final maxW =
                            constraints.maxWidth.isFinite &&
                                constraints.maxWidth > 0
                            ? constraints.maxWidth
                            : MediaQuery.sizeOf(context).width - 40;
                        final cellWidth = ((maxW - spacing) / crossAxisCount)
                            .clamp(100.0, double.infinity);
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: displayList
                              .map(
                                (user) => SizedBox(
                                  width: cellWidth,
                                  child: _UserGridCell(
                                    displayName: user.displayName ?? 'Unknown',
                                    photoURL: user.photoURL,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              UserDetailsPage(user: user),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  'Quick actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                _QuickActionCard(
                  title: 'Audio Reels',
                  icon: Icons.play_circle_fill_rounded,
                  splashColor: Colors.white.withValues(alpha: 0.3),
                  highlightColor: Colors.white.withValues(alpha: 0.15),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ReelsFeedPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _QuickActionCard(
                  title: 'Audio Streaming',
                  icon: Icons.radio_rounded,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BlocProvider<LiveHubBloc>.value(
                          value: context.read<LiveHubBloc>(),
                          child: const LiveHubPage(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid cell: card with avatar and name. Tappable to show user details.
class _UserGridCell extends StatelessWidget {
  const _UserGridCell({required this.displayName, this.photoURL, this.onTap});

  final String displayName;
  final String? photoURL;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '?';
    final hasPhoto = photoURL != null && photoURL!.isNotEmpty;
    final resolvedPhotoUrl = hasPhoto && !photoURL!.startsWith('http')
        ? '${AppConfig.baseUrl}$photoURL'
        : photoURL;
    final useNetwork =
        resolvedPhotoUrl != null && resolvedPhotoUrl.startsWith('http');
    final content = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.deepPurple.shade50,
              foregroundColor: Colors.deepPurple.shade700,
              backgroundImage: useNetwork
                  ? NetworkImage(resolvedPhotoUrl)
                  : null,
              child: useNetwork
                  ? null
                  : Text(
                      initial,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple.shade400,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
    return Material(
      color: Colors.transparent,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: content,
            )
          : content,
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.splashColor,
    this.highlightColor,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? splashColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: splashColor ?? Colors.white24,
        highlightColor: highlightColor ?? Colors.white12,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live now section: uses [LiveHubBloc] for real-time list of live streams.
class _LiveNowSection extends StatefulWidget {
  const _LiveNowSection();

  @override
  State<_LiveNowSection> createState() => _LiveNowSectionState();
}

class _LiveNowSectionState extends State<_LiveNowSection> {
  StreamSubscription<dynamic>? _startedSub;
  StreamSubscription<dynamic>? _endedSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedSub != null) return;
    final bloc = context.read<LiveHubBloc>();
    if (bloc.state is LiveHubInitial) {
      bloc.add(const LiveHubLoadSessions());
    }
    try {
      final signaling = context.read<SignalingService>();
      _startedSub = signaling.liveStarted.listen((payload) {
        if (!mounted) return;
        context.read<LiveHubBloc>().add(
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
        context.read<LiveHubBloc>().add(LiveHubSessionEnded(payload.sessionId));
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
    return BlocBuilder<LiveHubBloc, LiveHubState>(
      buildWhen: (prev, state) =>
          state is LiveHubInitial ||
          state is LiveHubLoading ||
          state is LiveHubLoaded,
      builder: (context, state) {
        final sessions = state is LiveHubLoaded ? state.sessions : <LiveSessionEntity>[];
        final loading = state is LiveHubLoading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live now',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            if (loading && sessions.isEmpty)
              SizedBox(height: 80, child: AppLoading.section(context))
            else if (sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No one is live. Tap "Audio Streaming" to go live.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              )
            else
              SizedBox(
                height: 88,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final s = sessions[index];
                final initial = s.hostDisplayName.isNotEmpty
                    ? s.hostDisplayName.substring(0, 1).toUpperCase()
                    : '?';
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 1,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LiveListenerPage(session: s),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 160,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.deepPurple.shade50,
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.deepPurple.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.hostDisplayName,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'LIVE',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
