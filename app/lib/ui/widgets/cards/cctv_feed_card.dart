import 'package:flutter/material.dart';

class CctvFeedCard extends StatelessWidget {
  final String cameraName;
  final String statusText;
  final Widget videoStreamChild;
  final VoidCallback? onFullscreen;
  final bool isRecording;

  const CctvFeedCard({
    super.key,
    required this.cameraName,
    required this.statusText,
    required this.videoStreamChild,
    this.onFullscreen,
    this.isRecording = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                videoStreamChild,
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRecording) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'REC',
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          statusText,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                if (onFullscreen != null)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: onFullscreen,
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.fullscreen, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: cs.surfaceContainerHigh,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cameraName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Icon(Icons.videocam_outlined, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
