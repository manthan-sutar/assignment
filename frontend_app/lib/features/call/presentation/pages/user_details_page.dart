import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/app_config.dart';
import '../../../../features/auth/domain/entities/display_user_entity.dart';
import '../../domain/repositories/call_repository.dart';
import '../../data/services/call_permission_service.dart';
import '../bloc/ringing/ringing_bloc.dart';
import '../bloc/ringing/ringing_event.dart';
import 'call_ringing_page.dart';

/// User profile screen: 1:1 profile image with name overlay, then swipe-to-call.
class UserDetailsPage extends StatefulWidget {
  const UserDetailsPage({super.key, required this.user});

  final DisplayUserEntity user;

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  /// Incremented when returning from call screen so swipe button resets and can be used again.
  int _swipeKey = 0;

  Future<void> _startCall(BuildContext context) async {
    final granted = await CallPermissionService().requestMicrophone();
    if (!mounted) return;
    if (!granted) {
      _showMicrophoneDeniedDialog(context);
      return;
    }
    final callRepo = context.read<CallRepository>();
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider<RingingBloc>(
              create: (ctx) =>
                  RingingBloc(callRepository: callRepo)
                    ..add(RingingCreateOffer(widget.user.id)),
              child: CallRingingPage(
                calleeDisplayName: widget.user.displayName ?? 'Unknown',
              ),
            ),
          ),
        )
        .then((_) {
          if (mounted) setState(() => _swipeKey++);
        });
  }

  void _showMicrophoneDeniedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Microphone required'),
        content: const Text(
          'Voice calls need microphone access. Please allow it in settings to call.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await CallPermissionService().openSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.user.displayName ?? 'Unknown';
    final initial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '?';
    final photoURL = widget.user.photoURL;
    final hasPhoto = photoURL != null && photoURL.isNotEmpty;
    final resolvedPhotoUrl = hasPhoto && !photoURL.startsWith('http')
        ? '${AppConfig.baseUrl}$photoURL'
        : photoURL;
    final useNetwork =
        resolvedPhotoUrl != null && resolvedPhotoUrl.startsWith('http');

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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1:1 profile image with name overlay and shadows
                    _ProfileHeader(
                      displayName: displayName,
                      initial: initial,
                      resolvedPhotoUrl: useNetwork ? resolvedPhotoUrl : null,
                    ),
                    const SizedBox(height: 32),
                    // Swipe to call (key resets when returning from call so user can swipe again)
                    _SwipeToCallButton(
                      key: ValueKey<int>(_swipeKey),
                      onCall: () => _startCall(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1:1 aspect ratio image with gradient overlay and name; consistent shadows.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.initial,
    this.resolvedPhotoUrl,
  });

  final String displayName;
  final String initial;
  final String? resolvedPhotoUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image or placeholder
                if (resolvedPhotoUrl != null)
                  Image.network(resolvedPhotoUrl!, fit: BoxFit.cover)
                else
                  Container(
                    color: Colors.deepPurple.shade50,
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: size * 0.35,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple.shade300,
                        ),
                      ),
                    ),
                  ),
                // Gradient overlay for name
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: size * 0.4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                // Name with shadow
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Swipe-right to confirm call: thumb slides across track; at 75% triggers call.
class _SwipeToCallButton extends StatefulWidget {
  const _SwipeToCallButton({super.key, required this.onCall});

  final VoidCallback onCall;

  @override
  State<_SwipeToCallButton> createState() => _SwipeToCallButtonState();
}

class _SwipeToCallButtonState extends State<_SwipeToCallButton> {
  double _dragOffset = 0;
  static const double _thumbWidth = 56;
  static const double _threshold = 0.75;
  bool _triggered = false;

  void _onCallTriggered() {
    if (_triggered) return;
    _triggered = true;
    widget.onCall();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxDrag = (width - _thumbWidth).clamp(0.0, double.infinity);

        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Track + label
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: _thumbWidth + 8),
                      child: Text(
                        'Swipe to call',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
                // Thumb
                Positioned(
                  left: _dragOffset,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) {
                      final newOffset = (_dragOffset + d.delta.dx).clamp(
                        0.0,
                        maxDrag,
                      );
                      if (maxDrag > 0 &&
                          newOffset >= maxDrag * _threshold &&
                          !_triggered) {
                        _onCallTriggered();
                      }
                      setState(() => _dragOffset = newOffset);
                    },
                    onHorizontalDragEnd: (_) {
                      setState(() => _dragOffset = 0);
                    },
                    child: Container(
                      width: _thumbWidth,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade400,
                            Colors.deepPurple.shade600,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
