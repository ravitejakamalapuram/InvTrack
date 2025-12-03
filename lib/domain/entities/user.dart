/// Represents an authenticated user in the application.
///
/// This entity contains user information obtained from Google Sign-In.
class User {
  /// Unique identifier from Google.
  final String id;

  /// User's email address.
  final String email;

  /// User's display name.
  final String? displayName;

  /// URL to user's profile photo.
  final String? photoUrl;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  /// Creates a copy of this user with the given fields replaced.
  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.displayName == displayName &&
        other.photoUrl == photoUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        email.hashCode ^
        displayName.hashCode ^
        photoUrl.hashCode;
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, displayName: $displayName)';
  }
}

