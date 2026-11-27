import 'package:material_ui/material_ui.dart';

/// Subtle top and bottom scrims that keep the HUD controls and status
/// readable over bright skies without dimming the centre of the camera view.
/// Ignores touches, so it never blocks the camera or the controls above it.
class ARHudEdgeScrim extends StatelessWidget {
  const ARHudEdgeScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x66000000),
              Color(0x12000000),
              Color(0x00000000),
              Color(0x18000000),
              Color(0x99000000),
            ],
            stops: [0, 0.18, 0.48, 0.72, 1],
          ),
        ),
      ),
    );
  }
}
