class UserEntity {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool isGuest;

  const UserEntity({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.isGuest = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserEntity &&
        other.id == id &&
        other.email == email &&
        other.displayName == displayName &&
        other.photoUrl == photoUrl &&
        other.isGuest == isGuest;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        email.hashCode ^
        displayName.hashCode ^
        photoUrl.hashCode ^
        isGuest.hashCode;
  }

  @override
  String toString() {
    return 'UserEntity(id: $id, email: $email, displayName: $displayName, photoUrl: $photoUrl, isGuest: $isGuest)';
  }
}
