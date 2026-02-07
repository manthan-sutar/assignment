import 'package:equatable/equatable.dart';

/// Lightweight user for "Find people" list (id, displayName, photoURL).
class DisplayUserEntity extends Equatable {
  const DisplayUserEntity({required this.id, this.displayName, this.photoURL});

  final String id;
  final String? displayName;
  final String? photoURL;

  @override
  List<Object?> get props => [id, displayName, photoURL];
}
