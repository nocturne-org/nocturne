import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/unified_queue_controller.dart';
import '../state/unified_queue_state.dart';

/// Provider fuer den einheitlichen Warteschlangen-Controller (Unified Queue).
final unifiedQueueControllerProvider =
    NotifierProvider<UnifiedQueueController, UnifiedQueueState>(
  UnifiedQueueController.new,
);
