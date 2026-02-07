/// Lightweight model for "Find people" list (id, displayName, photoURL).
class ListUserItem {
  const ListUserItem({required this.id, this.displayName, this.photoURL});

  final String id;
  final String? displayName;
  final String? photoURL;

  factory ListUserItem.fromJson(Map<String, dynamic> json) {
    return ListUserItem(
      id: json['id'] as String,
      displayName: json['displayName'] as String?,
      photoURL: json['photoURL'] as String?,
    );
  }
}
