// // lib/features/livestream/services/agora_service.dart
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';

// class AgoraService {
//   final RtcEngine _engine;
//   AgoraService._(this._engine);

//   static Future<AgoraService> create(String appId) async {
//     final engine = createAgoraRtcEngine();
//     await engine.initialize(RtcEngineContext(appId: appId));
//     return AgoraService._(engine);
//   }

//   Future<void> joinAsAudience({
//     required String channel,
//     required String token,
//     required String userAccount, // user UUID
//   }) async {
//     await _engine.setChannelProfile(
//       ChannelProfileType.channelProfileLiveBroadcasting,
//     );
//     await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);
//     await _engine.joinChannel(
//       token: token,
//       channelId: channel,
//       uid: 0,
//       options: const ChannelMediaOptions(
//         autoSubscribeAudio: true,
//         autoSubscribeVideo: true,
//       ),
//     );
//     await _engine.registerLocalUserAccount(
//       userAccount: userAccount,
//       appId: (await _engine.),
//     );
//   }

//   Future<void> joinAsPublisher({
//     required String channel,
//     required String token,
//     required String userAccount,
//   }) async {
//     await _engine.setChannelProfile(
//       ChannelProfileType.channelProfileLiveBroadcasting,
//     );
//     await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
//     await _engine.enableAudio();
//     await _engine.enableVideo();
//     await _engine.startPreview();
//     await _engine.joinChannel(
//       token: token,
//       channelId: channel,
//       uid: 0,
//       options: const ChannelMediaOptions(),
//     );
//     await _engine.registerLocalUserAccount(
//       userAccount: userAccount,
//       appId: (await _engine.getVersion()).appId,
//     );
//   }

//   Future<void> leave() async {
//     await _engine.leaveChannel();
//     await _engine.stopPreview();
//   }

//   RtcEngine get raw => _engine;
// }
