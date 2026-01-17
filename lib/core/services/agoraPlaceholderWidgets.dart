import 'package:flutter/material.dart';

/// A black placeholder widget with a white text in the center.
///
/// The widget takes a [String] parameter which is the text to be displayed.
///
/// The text is aligned to the center and has a font size of 14.
///
/// The widget is typically used as a placeholder when loading data.
Widget buildBlackPlaceholder(String text) {
  return Container(
    color: Colors.black,
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 14),
      ),
    ),
  );
}

Widget buildConnectingPlaceholder(String who) {
  return Center(
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Animated gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.black, Colors.grey.shade900],
            ),
          ),
        ),

        // // Big fainted video cancel icon
        // AnimatedOpacity(
        //   opacity: 0.15,
        //   duration: const Duration(milliseconds: 500),
        //   child: Container(
        //     padding: const EdgeInsets.all(60),
        //     decoration: BoxDecoration(
        //       shape: BoxShape.circle,
        //       border: Border.all(
        //         color: Colors.red.shade400.withOpacity(0.3),
        //         width: 2,
        //       ),
        //     ),
        //     child: Stack(
        //       alignment: Alignment.center,
        //       children: [
        //         // Circle
        //         Container(
        //           width: 120,
        //           height: 120,
        //           decoration: BoxDecoration(
        //             shape: BoxShape.circle,
        //             color: Colors.red.shade900.withOpacity(0.1),
        //             border: Border.all(
        //               color: Colors.red.shade800.withOpacity(0.2),
        //               width: 1,
        //             ),
        //           ),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),

        // Pulsing connection indicator
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated rings
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulsing ring
                AnimatedContainer(
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOut,
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.1),
                      width: 2,
                    ),
                  ),
                ),

                // Middle pulsing ring

                // X icon with gradient
                ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      colors: [
                        Colors.red.shade400.withOpacity(0.4),
                        Colors.orange.shade300.withOpacity(0.2),
                      ],
                    ).createShader(bounds);
                  },
                  child: const Icon(
                    Icons.videocam_off,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                // Main progress indicator
                // Container(
                //   width: 100,
                //   height: 100,
                //   // decoration: BoxDecoration(
                //   //   shape: BoxShape.circle,
                //   //   boxShadow: [
                //   //     BoxShadow(
                //   //       color: Colors.orange.withOpacity(0.4),
                //   //       blurRadius: 10,
                //   //       spreadRadius: 2,
                //   //     ),
                //   //   ],
                //   // ),
                //   child: CircularProgressIndicator(
                //     strokeWidth: 3,
                //     valueColor: AlwaysStoppedAnimation<Color>(
                //       Colors.orange.shade400.withOpacity(0.3),
                //     ),
                //     backgroundColor: Colors.orange.withOpacity(0.1),
                //   ),
                // ),
              ],
            ),

            const SizedBox(height: 24),

            // Modern text with gradient
            ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  colors: [Colors.white, Colors.grey.shade300],
                ).createShader(bounds);
              },
              child: Column(
                children: [
                  // Text(
                  //   'CONNECTION LOST',
                  //   style: TextStyle(
                  //     fontSize: 12,
                  //     fontWeight: FontWeight.w700,
                  //     letterSpacing: 2,
                  //     color: Colors.white,
                  //   ),
                  // ),
                  const SizedBox(height: 30),
                  // RichText(
                  //   text: TextSpan(
                  //     style: const TextStyle(
                  //       fontSize: 16,
                  //       fontWeight: FontWeight.w500,
                  //     ),
                  //     children: [
                  //       const TextSpan(
                  //         text: 'Lost connection with ',
                  //         style: TextStyle(color: Colors.white70),
                  //       ),
                  //       TextSpan(
                  //         text: who,
                  //         style: TextStyle(
                  //           color: Colors.orange.shade300,
                  //           fontWeight: FontWeight.w700,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
            ),

            // const SizedBox(height: 10),

            // // Subtle reconnect hint
            // AnimatedOpacity(
            //   opacity: 0.6,
            //   duration: const Duration(milliseconds: 800),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       Icon(
            //         Icons.wifi_off,
            //         size: 14,
            //         color: Colors.white.withOpacity(0.5),
            //       ),
            //       const SizedBox(width: 8),
            //       Text(
            //         'Attempting to reconnect...',
            //         style: TextStyle(
            //           color: Colors.white.withOpacity(0.7),
            //           fontSize: 12,
            //           letterSpacing: 0.5,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ],
    ),
  );
}

Widget buildVideoPlaceholder(String text) {
  return Container(
    color: Colors.black,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    ),
  );
}
