import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CctvFullscreenLayout extends StatefulWidget {
  final Widget videoStreamWidget;
  final Widget? overlayControls;
  final VoidCallback? onExitFullscreen;

  const CctvFullscreenLayout({
    super.key,
    required this.videoStreamWidget,
    this.overlayControls,
    this.onExitFullscreen,
  });

  @override
  State<CctvFullscreenLayout> createState() => _CctvFullscreenLayoutState();
}

class _CctvFullscreenLayoutState extends State<CctvFullscreenLayout> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: widget.videoStreamWidget),
          if (widget.overlayControls != null) widget.overlayControls!,
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 32),
              onPressed: () {
                if (widget.onExitFullscreen != null) {
                  widget.onExitFullscreen!();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
