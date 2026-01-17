import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class CoverHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 220,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(
                'https://images.unsplash.com/photo-1522202176988-66273c2fd55f',
              ),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 44,
          left: 16,
          child: _circleIcon(
            Icons.arrow_back_ios_new,
            () => Navigator.pop(context),
          ),
        ),
        Positioned(top: 44, right: 16, child: _circleIcon(Icons.share, () {})),
        Positioned(
          bottom: -36,
          left: 20,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bgBottom,
            ),
            child: const CircleAvatar(
              radius: 36,
              backgroundImage: NetworkImage(
                'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d',
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -36,
          left: 100,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Photography Enthusiasts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '2.4k members',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
