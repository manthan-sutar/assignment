import '../../domain/entities/user_entity.dart';

/**
 * User Model
 * Data layer representation of user
 * Extends UserEntity and adds JSON serialization
 */
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    super.email,
    required super.phoneNumber,
    super.displayName,
    super.photoURL,
    required super.firebaseUid,
  });

  /// Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String,
      displayName: json['displayName'] as String?,
      photoURL: json['photoURL'] as String?,
      firebaseUid: json['firebaseUid'] as String,
    );
  }

  /// Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoURL': photoURL,
      'firebaseUid': firebaseUid,
    };
  }

  /// Convert UserModel to UserEntity
  UserEntity toEntity() {
    return UserEntity(
      id: id,
      email: email,
      phoneNumber: phoneNumber,
      displayName: displayName,
      photoURL: photoURL,
      firebaseUid: firebaseUid,
    );
  }
}
