import 'package:equatable/equatable.dart';

/**
 * User Entity
 * Domain layer representation of a user
 * Independent of data source implementation
 */
class UserEntity extends Equatable {
  final String id;
  final String? email;
  final String phoneNumber;
  final String? displayName;
  final String? photoURL;
  final String firebaseUid;

  const UserEntity({
    required this.id,
    this.email,
    required this.phoneNumber,
    this.displayName,
    this.photoURL,
    required this.firebaseUid,
  });

  @override
  List<Object?> get props => [id, email, phoneNumber, displayName, photoURL, firebaseUid];
}
