import 'package:cloud_firestore/cloud_firestore.dart';

/// User stats stored in Firestore: streak, totals, badges.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.nickname,
    required this.streak,
    required this.totalObservations,
    required this.badges,
    required this.lastObservationAt,
  });

  final String uid;
  final String nickname;
  final int streak;
  final int totalObservations;
  final List<String> badges;
  final DateTime? lastObservationAt;

  UserProfile copyWith({
    String? nickname,
    int? streak,
    int? totalObservations,
    List<String>? badges,
    DateTime? lastObservationAt,
  }) {
    return UserProfile(
      uid: uid,
      nickname: nickname ?? this.nickname,
      streak: streak ?? this.streak,
      totalObservations: totalObservations ?? this.totalObservations,
      badges: badges ?? this.badges,
      lastObservationAt: lastObservationAt ?? this.lastObservationAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'nickname': nickname,
        'streak': streak,
        'totalObservations': totalObservations,
        'badges': badges,
        'lastObservationAt':
            lastObservationAt == null ? null : Timestamp.fromDate(lastObservationAt!),
      };

  factory UserProfile.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return UserProfile(
      uid: snap.id,
      nickname: data['nickname'] as String? ?? 'Botanist',
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      totalObservations: (data['totalObservations'] as num?)?.toInt() ?? 0,
      badges: ((data['badges'] as List?) ?? const []).cast<String>(),
      lastObservationAt:
          (data['lastObservationAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserProfile.initial(String uid) => UserProfile(
        uid: uid,
        nickname: 'Botanist #${uid.substring(0, uid.length.clamp(0, 4))}',
        streak: 0,
        totalObservations: 0,
        badges: const [],
        lastObservationAt: null,
      );
}
