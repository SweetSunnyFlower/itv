import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/models/vod_model.dart';
import 'tv_focusable.dart';

class VodCard extends StatelessWidget {
  final VodModel vod;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  const VodCard({
    super.key,
    required this.vod,
    required this.onTap,
    this.width = 120,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return TVFocusable(
      onSelect: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AspectRatio(
                aspectRatio: 120 / 170,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: vod.vodPic,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: const Color(0xFF2A2A2A),
                        child: const Center(child: Icon(Icons.movie_outlined, color: Colors.white24, size: 32)),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFF2A2A2A),
                        child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 32)),
                      ),
                    ),
                    if (vod.vodRemarks.isNotEmpty)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            vod.vodRemarks,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              vod.vodName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
