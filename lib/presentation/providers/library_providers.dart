import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/library_browser_controller.dart';
import '../state/library_browser_state.dart';

/// Provider fuer den Controller des Library Browsers.
final libraryBrowserControllerProvider =
    NotifierProvider<LibraryBrowserController, LibraryBrowserState>(
  LibraryBrowserController.new,
);
