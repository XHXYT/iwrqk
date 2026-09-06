import '../../const/iwara.dart';
import 'image.dart';

class UserModel {
  String id;
  String name;
  String username;
  String status;
  String role;
  bool followedBy;
  bool following;
  bool friend;
  bool premium;
  String? seenAt;
  ImageModel? avatar;
  String createdAt;
  String updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.status,
    required this.role,
    required this.followedBy,
    required this.following,
    required this.friend,
    required this.premium,
    this.seenAt,
    this.avatar,
    required this.createdAt,
    required this.updatedAt,
  });

  String get avatarUrl {
    if (avatar == null) return IwaraConst.defaultAvatarUrl;

    bool animated =
        avatar!.mime == "image/gif" ||
        avatar!.mime == "image/webp" ||
        avatar!.mime == "image/apng";

    if (animated) {
      return avatar!.getOriginalUrl();
    }

    return IwaraConst.avatarUrl
        .replaceFirst("{id}", avatar!.id)
        .replaceFirst("{name}", avatar!.name!);
  }

  String get avatarOriginalUrl {
    if (avatar == null) return IwaraConst.defaultAvatarUrl;

    return avatar!.getOriginalUrl();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      status: json['status'] as String? ?? '',
      role: json['role'] as String? ?? '',
      followedBy: json['followedBy'] as bool? ?? false,
      following: json['following'] as bool? ?? false,
      friend: json['friend'] as bool? ?? false,
      premium: json['premium'] as bool? ?? false,
      seenAt: json['seenAt'] as String?,
      avatar: json['avatar'] != null
          ? ImageModel.fromJson(json['avatar'])
          : null,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'status': status,
      'role': role,
      'followedBy': followedBy,
      'following': following,
      'friend': friend,
      'premium': premium,
      'seenAt': seenAt,
      'avatar': avatar?.toJson(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
