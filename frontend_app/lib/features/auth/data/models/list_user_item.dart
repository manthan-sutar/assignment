/// Lightweight model for "Find people" list (id, displayName, photoURL).
class ListUserItem {
  const ListUserItem({required this.id, this.displayName, this.photoURL});

  final String id;
  final String? displayName;
  final String? photoURL;

  factory ListUserItem.fromJson(Map<String, dynamic> json) {
    // Backend may return camelCase (photoURL) or snake_case (photo_url)
    final photoURL = json['photoURL'] as String? ?? json['photo_url'] as String?;
    final photo = (photoURL != null && photoURL.isNotEmpty) ? photoURL : null;
    return ListUserItem(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? json['display_name'] as String?,
      photoURL: photo,
    );
  }
}
