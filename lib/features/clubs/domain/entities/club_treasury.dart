// lib/features/clubs/domain/entities/club_treasury.dart

import 'package:equatable/equatable.dart';

// ── Summary ───────────────────────────────────────────────────────────────────

class ClubTreasurySummary extends Equatable {
  final int coinsTotal;
  final int coinsAvailable;
  final int coinsReserved;
  final double usdAvailable;
  final double usdTotalEarned;
  final double usdTotalWithdrawn;
  final bool treasuryReady;
  final bool isOwner;
  final bool isAdmin;
  final ClubTreasuryPolicy policy;
  final DateTime? lastWithdrawalAt;
  final DateTime? cooldownEndsAt;

  const ClubTreasurySummary({
    required this.coinsTotal,
    required this.coinsAvailable,
    required this.coinsReserved,
    required this.usdAvailable,
    required this.usdTotalEarned,
    required this.usdTotalWithdrawn,
    required this.treasuryReady,
    this.isOwner = false,
    this.isAdmin = false,
    required this.policy,
    this.lastWithdrawalAt,
    this.cooldownEndsAt,
  });

  bool get hasCooldown => cooldownEndsAt != null;

  factory ClubTreasurySummary.fromJson(Map<String, dynamic> j) {
    return ClubTreasurySummary(
      coinsTotal: (j['coins_total'] as num? ?? 0).toInt(),
      coinsAvailable: (j['coins_available'] as num? ?? 0).toInt(),
      coinsReserved: (j['coins_reserved'] as num? ?? 0).toInt(),
      usdAvailable: (j['usd_available'] as num? ?? 0).toDouble(),
      usdTotalEarned: (j['usd_total_earned'] as num? ?? 0).toDouble(),
      usdTotalWithdrawn: (j['usd_total_withdrawn'] as num? ?? 0).toDouble(),
      treasuryReady: j['treasury_ready'] as bool? ?? false,
      isOwner: j['is_owner'] as bool? ?? false,
      isAdmin: j['is_admin'] as bool? ?? false,
      policy: j['policy'] != null
          ? ClubTreasuryPolicy.fromJson(j['policy'])
          : const ClubTreasuryPolicy(),
      lastWithdrawalAt: j['last_withdrawal_at'] != null
          ? DateTime.tryParse(j['last_withdrawal_at'])
          : null,
      cooldownEndsAt: j['cooldown_ends_at'] != null
          ? DateTime.tryParse(j['cooldown_ends_at'])
          : null,
    );
  }

  @override
  List<Object?> get props => [
    coinsTotal, coinsAvailable, coinsReserved,
    usdAvailable, usdTotalEarned, usdTotalWithdrawn,
    treasuryReady, isOwner, isAdmin, // ← ADD both here too
    policy, lastWithdrawalAt, cooldownEndsAt,
  ];
}

class ClubTreasuryPolicy extends Equatable {
  final String quorum; // any | majority | all
  final double minAmountUsd;
  final int cooldownDays;
  final int expiryHours;

  const ClubTreasuryPolicy({
    this.quorum = 'any',
    this.minAmountUsd = 10,
    this.cooldownDays = 0,
    this.expiryHours = 72,
  });

  factory ClubTreasuryPolicy.fromJson(Map<String, dynamic> j) {
    return ClubTreasuryPolicy(
      quorum: j['quorum'] ?? 'any',
      minAmountUsd: (j['min_amount_usd'] as num?)?.toDouble() ?? 10,
      cooldownDays: j['cooldown_days'] ?? 0,
      expiryHours: j['expiry_hours'] ?? 72,
    );
  }

  @override
  List<Object?> get props => [quorum, minAmountUsd, cooldownDays, expiryHours];
}

// ── Withdrawal request ────────────────────────────────────────────────────────

class ClubWithdrawalRequest extends Equatable {
  final String uuid;
  final String status;
  final int amountCoins;
  final double amountUsd;
  final String paymentMethod;
  final String reason;
  final int approvalsRequired;
  final int approvalsReceived;
  final int rejections;
  final bool quorumReached;
  final bool canApprove;
  final bool canCancel;
  final String? viewerVote;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final ClubWithdrawalRequester? requester;
  final List<ClubWithdrawalVote> votes;

  // Full detail fields (only in showRequest)
  final String? bankAccountName;
  final String? bankAccountMasked;
  final String? bankName;
  final String? bankCountry;
  final String? paypalEmail;
  final String? flwReference;

  const ClubWithdrawalRequest({
    required this.uuid,
    required this.status,
    required this.amountCoins,
    required this.amountUsd,
    required this.paymentMethod,
    required this.reason,
    required this.approvalsRequired,
    required this.approvalsReceived,
    required this.rejections,
    required this.quorumReached,
    required this.canApprove,
    required this.canCancel,
    this.viewerVote,
    this.expiresAt,
    this.createdAt,
    this.completedAt,
    this.requester,
    this.votes = const [],
    this.bankAccountName,
    this.bankAccountMasked,
    this.bankName,
    this.bankCountry,
    this.paypalEmail,
    this.flwReference,
  });

  bool get isPending => status == 'pending_approval';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get isTerminal => [
    'completed',
    'failed',
    'rejected',
    'cancelled',
    'expired',
  ].contains(status);

  bool get hasExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now()) && isPending;

  factory ClubWithdrawalRequest.fromJson(Map<String, dynamic> j) {
    return ClubWithdrawalRequest(
      uuid: j['uuid'],
      status: j['status'],
      amountCoins: int.tryParse(j['amount_coins'].toString()) ?? 0,
      amountUsd: (j['amount_usd'] as num?)?.toDouble() ?? 0,
      paymentMethod: j['payment_method'] ?? 'flutterwave',
      reason: j['reason'] ?? '',
      approvalsRequired: int.tryParse(j['approvals_required'].toString()) ?? 0,
      approvalsReceived: j['approvals_received'] ?? 0,
      rejections: j['rejections'] ?? 0,
      quorumReached: j['quorum_reached'] ?? false,
      canApprove: j['can_approve'] ?? false,
      canCancel: j['can_cancel'] ?? false,
      viewerVote: j['viewer_vote'],
      expiresAt: j['expires_at'] != null
          ? DateTime.tryParse(j['expires_at'])
          : null,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'])
          : null,
      completedAt: j['completed_at'] != null
          ? DateTime.tryParse(j['completed_at'])
          : null,
      requester: j['requester'] != null
          ? ClubWithdrawalRequester.fromJson(j['requester'])
          : null,
      votes: (j['votes'] as List? ?? [])
          .map((v) => ClubWithdrawalVote.fromJson(v))
          .toList(),
      bankAccountName: j['bank_account_name'],
      bankAccountMasked: j['bank_account_masked'],
      bankName: j['bank_name'],
      bankCountry: j['bank_country'],
      paypalEmail: j['paypal_email'],
      flwReference: j['flw_reference'],
    );
  }

  @override
  List<Object?> get props => [uuid, status, approvalsReceived, viewerVote];
}

class ClubWithdrawalRequester extends Equatable {
  final String uuid;
  final String? userSlug;
  final String? fullname;
  final String? avatarUrl;

  const ClubWithdrawalRequester({
    required this.uuid,
    this.userSlug,
    this.fullname,
    this.avatarUrl,
  });

  factory ClubWithdrawalRequester.fromJson(Map<String, dynamic> j) {
    return ClubWithdrawalRequester(
      uuid: j['uuid'],
      userSlug: j['user_slug'],
      fullname: j['fullname'],
      avatarUrl: j['avatar_url'],
    );
  }

  @override
  List<Object?> get props => [uuid];
}

class ClubWithdrawalVote extends Equatable {
  final String action; // approved | rejected
  final String? note;
  final DateTime? createdAt;
  final ClubWithdrawalRequester? admin;

  const ClubWithdrawalVote({
    required this.action,
    this.note,
    this.createdAt,
    this.admin,
  });

  factory ClubWithdrawalVote.fromJson(Map<String, dynamic> j) {
    return ClubWithdrawalVote(
      action: j['action'],
      note: j['note'],
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'])
          : null,
      admin: j['admin'] != null
          ? ClubWithdrawalRequester.fromJson(j['admin'])
          : null,
    );
  }

  @override
  List<Object?> get props => [action, admin?.uuid];
}
