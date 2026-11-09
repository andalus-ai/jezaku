import 'package:flutter/material.dart';
import 'package:jejaku/app/screens/main_screen.dart';
import 'package:jejaku/features/ar_viewer/screens/ar_viewer_screen.dart';
import 'package:jejaku/features/calibration/screens/calibration_review_screen.dart';
import 'package:jejaku/features/camera/screens/camera_screen.dart';
import 'package:jejaku/features/gallery/screens/gallery_screen.dart';
import 'package:jejaku/features/home/screens/memory_calibration_screen.dart';
import 'package:jejaku/features/home/screens/memory_detail_screen.dart';
import 'package:jejaku/features/home/screens/memory_search_screen.dart';
import 'package:jejaku/features/moderation/screens/moderation_queue_screen.dart';
import 'package:jejaku/features/parent/screens/parent_dashboard_screen.dart';
import 'package:jejaku/features/publish/screens/publish_screen.dart';
import 'package:jejaku/features/settings/screens/privacy_safety_screen.dart';
import 'package:jejaku/features/settings/screens/settings_screen.dart';
import 'package:jejaku/features/social/screens/messages_screen.dart';
import 'package:jejaku/features/social/screens/notifications_screen.dart';
import 'package:jejaku/features/sync/screens/sync_queue_screen.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/virtual_wall/screens/virtual_wall_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const root = '/';
  static const arViewer = '/ar-viewer';
  static const calibrationReview = '/calibration-review';
  static const camera = '/camera';
  static const gallery = '/gallery';
  static const memoryCalibration = '/memory-calibration';
  static const memoryDetails = '/memory-details';
  static const memorySearch = '/memory-search';
  static const moderationQueue = '/moderation-queue';
  static const parentDashboard = '/parent-dashboard';
  static const publish = '/publish';
  static const privacySafety = '/settings/privacy-safety';
  static const settings = '/settings';
  static const socialMessages = '/social/messages';
  static const socialNotifications = '/social/notifications';
  static const syncQueue = '/sync-queue';
  static const virtualWallDetails = '/virtual-walls/detail';
  static const virtualWalls = '/virtual-walls';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final builder = switch (settings.name) {
      root => (_) => const MainScreen(),
      arViewer => (_) {
          final args = settings.arguments;
          if (args is ARViewerArgs) {
            return ARViewerScreen(
              focusedMemoryId: args.focusedMemoryId,
              journeyMemoryIds: args.journeyMemoryIds,
              journeyTitle: args.journeyTitle,
              sourceWallId: args.sourceWallId,
              trailSession: args.trailSession,
              resumeExistingProgress: args.resumeExistingProgress,
            );
          }
          if (args is String) {
            return ARViewerScreen(focusedMemoryId: args);
          }
          return const ARViewerScreen();
        },
      calibrationReview => (_) => const CalibrationReviewScreen(),
      camera => (_) => const CameraScreen(),
      gallery => (_) => const GalleryScreen(),
      memoryCalibration => (_) => MemoryCalibrationScreen(
            memoryId: settings.arguments as String? ?? '',
          ),
      memoryDetails => (_) => MemoryDetailScreen(
            memoryId: settings.arguments as String? ?? '',
          ),
      memorySearch => (_) {
          final args = settings.arguments;
          if (args is MemorySearchArgs) {
            return MemorySearchScreen(
              initialQuery: args.initialQuery,
              initialFilter: args.initialFilter,
            );
          }
          return const MemorySearchScreen();
        },
      moderationQueue => (_) => const ModerationQueueScreen(),
      parentDashboard => (_) => const ParentDashboardScreen(),
      publish => (_) => const PublishScreen(),
      privacySafety => (_) => const PrivacySafetyScreen(),
      AppRoutes.settings => (_) => const SettingsScreen(),
      socialMessages => (_) => const MessagesScreen(),
      socialNotifications => (_) => const NotificationsScreen(),
      syncQueue => (_) => const SyncQueueScreen(),
      virtualWallDetails => (_) => VirtualWallDetailScreen(
            wallId: settings.arguments as String? ?? '',
          ),
      virtualWalls => (_) => const VirtualWallScreen(),
      _ => (_) => const MainScreen(),
    };

    return MaterialPageRoute<void>(
      builder: builder,
      settings: settings,
    );
  }
}

class ARViewerArgs {
  const ARViewerArgs({
    this.focusedMemoryId,
    this.journeyMemoryIds = const [],
    this.journeyTitle,
    this.sourceWallId,
    this.trailSession,
    this.resumeExistingProgress = false,
  });

  factory ARViewerArgs.trail(ARTrailSession trailSession) {
    return ARViewerArgs(
      focusedMemoryId: trailSession.initialMemoryId,
      journeyMemoryIds: trailSession.memoryIds,
      journeyTitle: trailSession.title,
      sourceWallId: trailSession.sourceWallId,
      trailSession: trailSession,
    );
  }

  factory ARViewerArgs.resume(ARTrailProgress progress) {
    return ARViewerArgs(
      focusedMemoryId: progress.currentMemoryId,
      journeyMemoryIds: progress.session.memoryIds,
      journeyTitle: progress.session.title,
      sourceWallId: progress.session.sourceWallId,
      trailSession: progress.session,
      resumeExistingProgress: true,
    );
  }

  final String? focusedMemoryId;
  final List<String> journeyMemoryIds;
  final String? journeyTitle;
  final String? sourceWallId;
  final ARTrailSession? trailSession;
  final bool resumeExistingProgress;
}
