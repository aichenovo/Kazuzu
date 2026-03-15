import 'dart:io';
import 'package:flutter/material.dart';
import 'package:aura/app_module.dart';
import 'package:aura/app_widget.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:aura/bean/settings/theme_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aura/utils/storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:aura/request/request.dart';
import 'package:aura/utils/proxy_manager.dart';
import 'package:flutter/services.dart';
import 'package:aura/utils/utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aura/pages/error/storage_error_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:aura/utils/tmdb_migration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ));
  }

  if (Platform.isAndroid) {
    await Utils.checkWebViewFeatureSupport();
  }

  try {
    await Hive.initFlutter(
        '${(await getApplicationSupportDirectory()).path}/hive');
    await GStorage.init();
  } catch (_) {
    if (Platform.isWindows) {
      await windowManager.ensureInitialized();
      windowManager.waitUntilReadyToShow(null, () async {
        // Native window show has been blocked in `flutter_windows.cppL36` to avoid flickering.
        // Without this. the window will never show on Windows.
        await windowManager.show();
        await windowManager.focus();
      });
    }
    runApp(MaterialApp(
        title: '初始化失败',
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [
          Locale.fromSubtags(
              languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN")
        ],
        locale: const Locale.fromSubtags(
            languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN"),
        builder: (context, child) {
          return const StorageErrorPage();
        }));
    return;
  }
  bool showWindowButton = await GStorage.setting
      .get(SettingBoxKey.showWindowButton, defaultValue: false);
  if (Utils.isDesktop()) {
    await windowManager.ensureInitialized();
    bool isLowResolution = await Utils.isLowResolution();
    WindowOptions windowOptions = WindowOptions(
      size: isLowResolution ? const Size(840, 600) : const Size(1280, 860),
      center: true,
      skipTaskbar: false,
      // macOS always hide title bar regardless of showWindowButton setting
      titleBarStyle: (Platform.isMacOS || !showWindowButton)
          ? TitleBarStyle.hidden
          : TitleBarStyle.normal,
      windowButtonVisibility: showWindowButton,
      title: 'Aura',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      // Native window show has been blocked in `flutter_windows.cppL36` to avoid flickering.
      // Without this. the window will never show on Windows.
      await windowManager.show();
      await windowManager.focus();
    });
  }
  Request();
  await Request.setCookie();
  ProxyManager.applyProxy();
  Future.microtask(() => TmdbMigration.migrateIfNeeded());
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: ModularApp(
        module: AppModule(),
        child: const AppWidget(),
      ),
    ),
  );
}
