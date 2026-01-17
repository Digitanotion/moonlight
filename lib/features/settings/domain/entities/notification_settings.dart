import 'package:equatable/equatable.dart';

class NotificationSettings extends Equatable {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool liveAlertsEnabled;
  final bool giftAlertsEnabled;
  final bool messageNotifications;
  final bool followNotifications;
  final bool clubNotifications;

  const NotificationSettings({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.liveAlertsEnabled,
    required this.giftAlertsEnabled,
    required this.messageNotifications,
    required this.followNotifications,
    required this.clubNotifications,
  });

  Map<String, dynamic> toJson() {
    return {
      'push_enabled': pushEnabled,
      'email_enabled': emailEnabled,
      'live_alerts_enabled': liveAlertsEnabled,
      'gift_alerts_enabled': giftAlertsEnabled,
      'message_notifications': messageNotifications,
      'follow_notifications': followNotifications,
      'club_notifications': clubNotifications,
    };
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      pushEnabled: json['push_enabled'] as bool? ?? true,
      emailEnabled: json['email_enabled'] as bool? ?? true,
      liveAlertsEnabled: json['live_alerts_enabled'] as bool? ?? true,
      giftAlertsEnabled: json['gift_alerts_enabled'] as bool? ?? true,
      messageNotifications: json['message_notifications'] as bool? ?? true,
      followNotifications: json['follow_notifications'] as bool? ?? true,
      clubNotifications: json['club_notifications'] as bool? ?? true,
    );
  }

  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? liveAlertsEnabled,
    bool? giftAlertsEnabled,
    bool? messageNotifications,
    bool? followNotifications,
    bool? clubNotifications,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      liveAlertsEnabled: liveAlertsEnabled ?? this.liveAlertsEnabled,
      giftAlertsEnabled: giftAlertsEnabled ?? this.giftAlertsEnabled,
      messageNotifications: messageNotifications ?? this.messageNotifications,
      followNotifications: followNotifications ?? this.followNotifications,
      clubNotifications: clubNotifications ?? this.clubNotifications,
    );
  }

  @override
  List<Object?> get props => [
    pushEnabled,
    emailEnabled,
    liveAlertsEnabled,
    giftAlertsEnabled,
    messageNotifications,
    followNotifications,
    clubNotifications,
  ];
}
