// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:uuid/uuid.dart';
// import 'package:moonlight/core/routing/route_names.dart';
// import 'package:moonlight/core/theme/app_colors.dart';
// import 'package:moonlight/core/utils/formatting.dart';
// import 'package:moonlight/features/home/domain/entities/live_item.dart';
// import 'package:moonlight/widgets/image_placeholder.dart';
// import 'package:moonlight/features/wallet/services/idempotency_helper.dart';
// import 'package:moonlight/features/home/domain/repositories/live_feed_repository.dart';
// import 'package:moonlight/widgets/top_snack.dart';
// import '../../../../core/injection_container.dart';

// class LiveCardVertical extends StatelessWidget {
//   final LiveItem item;
//   const LiveCardVertical({super.key, required this.item});

//   @override
//   Widget build(BuildContext context) {
//     final flag = isoToFlagEmoji(item.countryIso2 ?? '');
//     final countryName = item.countryName ?? 'Unknown';
//     final viewersText = formatCompact(item.viewers);

//     return InkWell(
//       borderRadius: BorderRadius.circular(16),
//       onTap: () {
//         print("Is premium: " + item.isPremium.toString());
//         if ((item.isPremium ?? 0) == 1) {
//           _showPremiumConfirmBottomSheet(context, item);
//         } else {
//           Navigator.of(context).pushNamed(
//             RouteNames.liveViewer,
//             arguments: {
//               'id': item.id, // ✅ numeric id for Pusher channels
//               'uuid': item.uuid, // ✅ REST accepts uuid or numeric
//               'channel': item.channel,
//               'hostName': item.handle.replaceFirst('@', ''),
//               'hostAvatar': item.coverUrl, // if you have it
//               'title': item.title, // if you have it
//               'startedAt': item.startedAt, // ISO8601 if present
//               'role': item.role,
//             },
//           );
//         }
//       },
//       child: Container(
//         height: 220,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(16),
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [
//               Colors.white.withOpacity(0.06),
//               Colors.white.withOpacity(0.02),
//             ],
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.15),
//               blurRadius: 16,
//               offset: const Offset(0, 8),
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(16),
//           child: Stack(
//             children: [
//               // Thumbnail (cover_url)
//               Positioned.fill(
//                 child: NetworkImageWithPlaceholder(
//                   url: item.coverUrl,
//                   fit: BoxFit.cover,
//                   borderRadius: BorderRadius.circular(16),
//                   shimmer: true,
//                   icon: Icons.videocam_rounded,
//                 ),
//               ),
//               // Overlay gradient
//               Positioned.fill(
//                 child: DecoratedBox(
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.bottomCenter,
//                       end: Alignment.topCenter,
//                       colors: [
//                         Colors.black.withOpacity(0.6),
//                         Colors.black.withOpacity(0.15),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),

//               // LIVE + viewers (top)
//               Positioned(
//                 top: 10,
//                 left: 10,
//                 right: 10,
//                 child: Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 8,
//                         vertical: 4,
//                       ),
//                       decoration: BoxDecoration(
//                         color: AppColors.textRed,
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Text(
//                         'LIVE',
//                         style: Theme.of(context).textTheme.labelSmall?.copyWith(
//                           color: Colors.white,
//                           fontWeight: FontWeight.w800,
//                           letterSpacing: 0.3,
//                         ),
//                       ),
//                     ),
//                     const Spacer(),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 8,
//                         vertical: 4,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.35),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Row(
//                         children: [
//                           const Icon(
//                             Icons.remove_red_eye_outlined,
//                             size: 14,
//                             color: Colors.white,
//                           ),
//                           const SizedBox(width: 4),
//                           Text(
//                             viewersText,
//                             style: Theme.of(context).textTheme.labelSmall
//                                 ?.copyWith(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w700,
//                                 ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               // Bottom details: @user_slug, role, Flag + Country
//               Positioned(
//                 left: 12,
//                 right: 12,
//                 bottom: 12,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // @user_slug
//                     Text(
//                       item.handle, // already "@user_slug"
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: Theme.of(context).textTheme.bodyLarge?.copyWith(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w800,
//                       ),
//                     ),
//                     const SizedBox(height: 6),
//                     // role
//                     Text(
//                       item.role,
//                       style: Theme.of(context).textTheme.labelSmall?.copyWith(
//                         color: Colors.white70,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     const SizedBox(height: 6),
//                     // Flag + Country
//                     Row(
//                       children: [
//                         Text(flag, style: const TextStyle(fontSize: 16)),
//                         const SizedBox(width: 6),
//                         Text(
//                           countryName,
//                           style: const TextStyle(
//                             fontSize: 12,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _showPremiumConfirmBottomSheet(BuildContext context, LiveItem item) {
//     final repo = sl<LiveFeedRepository>();
//     final idempo = sl<IdempotencyHelper>();
//     final uuid = const Uuid();

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (ctx) {
//         bool isLoading = false;
//         String? statusMessage;
//         int? newBalance;

//         return StatefulBuilder(
//           builder: (context, setState) {
//             return Padding(
//               padding: EdgeInsets.only(
//                 left: 16,
//                 right: 16,
//                 bottom: MediaQuery.of(context).viewInsets.bottom + 16,
//                 top: 16,
//               ),
//               child: Material(
//                 borderRadius: BorderRadius.circular(16),
//                 color: const Color(0xFF0B0B0D),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const SizedBox(height: 12),
//                     Container(
//                       width: 40,
//                       height: 6,
//                       decoration: BoxDecoration(
//                         color: Colors.white12,
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     ListTile(
//                       leading: ClipRRect(
//                         borderRadius: BorderRadius.circular(8),
//                         child: NetworkImageWithPlaceholder(
//                           url: item.coverUrl,
//                           fit: BoxFit.cover,
//                           borderRadius: BorderRadius.circular(8),
//                           shimmer: false,
//                           icon: Icons.videocam_rounded,
//                         ),
//                       ),
//                       title: Text(
//                         item.title ?? 'Premium Stream',
//                         style: const TextStyle(
//                           fontWeight: FontWeight.w800,
//                           color: Colors.white,
//                         ),
//                       ),
//                       subtitle: Text(
//                         item.handle.replaceFirst('@', ''),
//                         style: const TextStyle(color: Colors.white70),
//                       ),
//                     ),

//                     Padding(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 12,
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Premium access required',
//                             style: TextStyle(color: Colors.white70),
//                           ),
//                           const SizedBox(height: 8),
//                           const Text(
//                             'Stream fee will be deducted from your wallet.',
//                             style: TextStyle(color: Colors.white70),
//                           ),
//                           const SizedBox(height: 12),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               const Text(
//                                 'Your wallet balance',
//                                 style: TextStyle(color: Colors.white70),
//                               ),
//                               Text(
//                                 newBalance != null
//                                     ? '$newBalance coins'
//                                     : '— coins',
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w800,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           if (statusMessage != null) ...[
//                             const SizedBox(height: 12),
//                             Text(
//                               statusMessage!,
//                               style: const TextStyle(color: Colors.redAccent),
//                             ),
//                           ],
//                           const SizedBox(height: 16),
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: ElevatedButton(
//                                   onPressed: isLoading
//                                       ? null
//                                       : () async {
//                                           setState(() => isLoading = true);
//                                           final idempotencyKey = uuid.v4();
//                                           await idempo.persist(idempotencyKey, {
//                                             'liveId': item.id,
//                                           });
//                                           try {
//                                             final resp = await repo.payPremium(
//                                               liveId: item.id,
//                                               idempotencyKey: idempotencyKey,
//                                             );

//                                             final status =
//                                                 (resp['status'] ?? '')
//                                                     as String;
//                                             if (status.toLowerCase() ==
//                                                 'success') {
//                                               final data =
//                                                   resp['data']
//                                                       as Map<String, dynamic>?;
//                                               if (data != null &&
//                                                   data['new_balance_coins'] !=
//                                                       null) {
//                                                 newBalance =
//                                                     (data['new_balance_coins']
//                                                             as num)
//                                                         .toInt();
//                                                 // TODO: update global wallet state (dispatch wallet update)
//                                               }

//                                               await idempo.complete(
//                                                 idempotencyKey,
//                                               );

//                                               TopSnack.success(
//                                                 context,
//                                                 data != null &&
//                                                         data['message'] != null
//                                                     ? data['message'] as String
//                                                     : 'Premium paid',
//                                               );
//                                               Navigator.of(
//                                                 context,
//                                               ).pop(); // close sheet

//                                               // Navigate to viewer
//                                               Navigator.of(context).pushNamed(
//                                                 RouteNames.liveViewer,
//                                                 arguments: {
//                                                   'id': item.id,
//                                                   'uuid': item.uuid,
//                                                   'channel': item.channel,
//                                                   'hostName': item.handle
//                                                       .replaceFirst('@', ''),
//                                                   'hostAvatar': item.coverUrl,
//                                                   'title': item.title,
//                                                   'startedAt': item.startedAt,
//                                                   'role': item.role,
//                                                 },
//                                               );
//                                               return;
//                                             } else {
//                                               final message =
//                                                   resp['message'] as String? ??
//                                                   'Payment failed';
//                                               if (message
//                                                   .toLowerCase()
//                                                   .contains('insufficient')) {
//                                                 setState(
//                                                   () => statusMessage =
//                                                       'Insufficient coins. Open wallet to buy coins.',
//                                                 );
//                                                 TopSnack.error(
//                                                   context,
//                                                   'Insufficient coins.',
//                                                 );
//                                                 // keep persisted key so recovery is possible if desired
//                                               } else if (message
//                                                       .toLowerCase()
//                                                       .contains(
//                                                         'unauthorized',
//                                                       ) ||
//                                                   message
//                                                       .toLowerCase()
//                                                       .contains('unauth')) {
//                                                 setState(
//                                                   () => statusMessage =
//                                                       'You are not allowed to view this stream.',
//                                                 );
//                                                 TopSnack.error(
//                                                   context,
//                                                   'This action is unauthorized.',
//                                                 );
//                                                 // remove persisted entry because it won't succeed
//                                                 await idempo.complete(
//                                                   idempotencyKey,
//                                                 );
//                                               } else {
//                                                 setState(
//                                                   () => statusMessage = message,
//                                                 );
//                                                 TopSnack.error(
//                                                   context,
//                                                   message,
//                                                 );
//                                               }
//                                             }
//                                           } catch (e) {
//                                             setState(
//                                               () => statusMessage =
//                                                   'Network error. Please try again.',
//                                             );
//                                             TopSnack.error(
//                                               context,
//                                               'Network error. Please try again.',
//                                             );
//                                             // keep persisted key so recovery is possible.
//                                           } finally {
//                                             setState(() => isLoading = false);
//                                           }
//                                         },
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: AppColors.primary,
//                                     padding: const EdgeInsets.symmetric(
//                                       vertical: 14,
//                                     ),
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                   ),
//                                   child: isLoading
//                                       ? const SizedBox(
//                                           height: 18,
//                                           width: 18,
//                                           child: CircularProgressIndicator(
//                                             strokeWidth: 2,
//                                           ),
//                                         )
//                                       : const Text(
//                                           'Proceed',
//                                           style: TextStyle(
//                                             fontWeight: FontWeight.w800,
//                                           ),
//                                         ),
//                                 ),
//                               ),
//                               const SizedBox(width: 12),
//                               OutlinedButton(
//                                 onPressed: () {
//                                   Navigator.of(context).pop();
//                                   Navigator.of(context).pushNamed('/wallet');
//                                 },
//                                 style: OutlinedButton.styleFrom(
//                                   side: BorderSide(color: Colors.white12),
//                                   padding: const EdgeInsets.symmetric(
//                                     vertical: 14,
//                                     horizontal: 16,
//                                   ),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                 ),
//                                 child: const Text(
//                                   'Open Wallet',
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.w800,
//                                     color: Colors.white,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 12),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
// }
