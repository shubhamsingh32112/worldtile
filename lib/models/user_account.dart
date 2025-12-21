/// UserAccount model representing full user account data
class UserAccount {
  final String name;
  final String email;
  final String? photoUrl;
  final String? walletAddress;
  final String? referralCode;
  final String? referredBy; // ID of the user who referred this user
  final AgentProfile agentProfile;
  final ReferralStats referralStats;
  final DateTime createdAt;

  UserAccount({
    required this.name,
    required this.email,
    this.photoUrl,
    this.walletAddress,
    this.referralCode,
    this.referredBy,
    required this.agentProfile,
    required this.referralStats,
    required this.createdAt,
  });

  /// Check if user has been referred (referredBy is not null)
  bool get isReferred => referredBy != null;

  /// Check if user can add a referral code (not yet referred)
  bool get canAddReferralCode => !isReferred;

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      name: json['name'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?,
      walletAddress: json['walletAddress'] as String?,
      referralCode: json['referralCode'] as String?,
      referredBy: json['referredBy'] as String?,
      agentProfile: AgentProfile.fromJson(
        json['agentProfile'] as Map<String, dynamic>,
      ),
      referralStats: ReferralStats.fromJson(
        json['referralStats'] as Map<String, dynamic>,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'walletAddress': walletAddress,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'agentProfile': agentProfile.toJson(),
      'referralStats': referralStats.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Get initials for avatar display
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[parts.length - 1].substring(0, 1))
        .toUpperCase();
  }
}

/// Agent profile information
class AgentProfile {
  final String title;
  final double commissionRate; // 0.0 to 1.0
  final DateTime joinedAt;

  AgentProfile({
    required this.title,
    required this.commissionRate,
    required this.joinedAt,
  });

  /// Get commission rate as percentage (e.g., 0.25 -> 25%)
  int get commissionRatePercent => (commissionRate * 100).round();

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    return AgentProfile(
      title: json['title'] as String,
      commissionRate: (json['commissionRate'] as num).toDouble(),
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'commissionRate': commissionRate,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }
}

/// Referral statistics
class ReferralStats {
  final int totalReferrals;
  final String totalEarningsUSDT; // Store as string to avoid precision issues

  ReferralStats({
    required this.totalReferrals,
    required this.totalEarningsUSDT,
  });

  /// Get earnings as double (for display)
  double get earningsAsDouble {
    try {
      return double.parse(totalEarningsUSDT);
    } catch (e) {
      return 0.0;
    }
  }

  factory ReferralStats.fromJson(Map<String, dynamic> json) {
    return ReferralStats(
      totalReferrals: (json['totalReferrals'] as num).toInt(),
      totalEarningsUSDT: json['totalEarningsUSDT'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalReferrals': totalReferrals,
      'totalEarningsUSDT': totalEarningsUSDT,
    };
  }
}

