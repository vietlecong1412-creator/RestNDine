// Bộ chụp màn hình mọi màn hình (sáng/tối) bằng dữ liệu giả lập — để rà soát giao diện
// hoặc lấy ảnh minh hoạ cho báo cáo. Không chạy cùng `flutter test` thông thường.
//
//   flutter test test/screenshots --dart-define=SHOTS_DIR=build/shots
//
// Tuỳ chọn --dart-define=TILES_DIR=<thư mục> chứa tile bản đồ dạng {z}_{x}_{y}.jpg;
// thiếu tile thì nền bản đồ để trơn và danh sách tile còn thiếu ghi vào missing_tiles.txt.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restndine_app/config/app_theme.dart';
import 'package:restndine_app/config/map_tiles.dart';
import 'package:restndine_app/models/place_model.dart';
import 'package:restndine_app/providers/auth_provider.dart';
import 'package:restndine_app/providers/location_provider.dart';
import 'package:restndine_app/providers/route_provider.dart';
import 'package:restndine_app/providers/place_provider.dart';
import 'package:restndine_app/screens/auth/login_screen.dart';
import 'package:restndine_app/screens/auth/otp_screen.dart';
import 'package:restndine_app/screens/auth/register_screen.dart';
import 'package:restndine_app/screens/chat/chat_screen.dart';
import 'package:restndine_app/screens/place_detail/place_detail_screen.dart';
import 'package:restndine_app/screens/place_detail/widgets/review_widgets.dart';
import 'package:restndine_app/screens/shell/main_shell.dart';
import 'package:restndine_app/services/api_service.dart';
import 'package:restndine_app/widgets/place_image.dart';

import 'fixtures.dart' as fx;

const _outDir = String.fromEnvironment('SHOTS_DIR');
const _tilesDir = String.fromEnvironment('TILES_DIR', defaultValue: 'build/tiles');
final _sdkFonts = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';

final _shotKey = GlobalKey();
final _images = <String, MemoryImage>{};
final _tileImages = <String, MemoryImage>{};
final _missingTiles = <String>{};
late MemoryImage _blankTile;

// ---------------------------------------------------------------- fake API

class _FakeAdapter implements HttpClientAdapter {
  bool failAll = false;
  bool emptyChat = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (failAll) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    }
    final path = options.uri.path;
    Object? data;
    if (path == '/api/places/categories') {
      data = fx.categories;
    } else if (path == '/api/places') {
      data = fx.places;
    } else if (RegExp(r'^/api/places/\d+$').hasMatch(path)) {
      data = fx.placeDetail(int.parse(path.split('/').last));
    } else if (RegExp(r'^/api/places/\d+/ai-summary$').hasMatch(path)) {
      data = fx.aiSummary();
    } else if (path == '/api/auth/me') {
      data = {'success': true, 'user': _currentUser};
    } else if (path == '/api/chat/messages') {
      data = {'success': true, 'messages': emptyChat ? [] : fx.chatMessages()};
    } else {
      return ResponseBody.fromString('{"message":"not found"}', 404,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    return ResponseBody.fromString(jsonEncode(data), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

final _adapter = _FakeAdapter();
Map<String, dynamic> _currentUser = fx.customer;

// ---------------------------------------------------------------- tiles & images

class _LocalTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates c, TileLayer options) {
    final key = '${c.z}_${c.x}_${c.y}';
    final cached = _tileImages[key];
    if (cached != null) return cached;
    final f = File('$_tilesDir/$key.jpg');
    if (f.existsSync()) return _tileImages[key] = MemoryImage(f.readAsBytesSync());
    _missingTiles.add(key);
    return _blankTile;
  }
}

String _imageKey(String url) {
  final m = RegExp(r'(restaurant|cafe|hotel)-\d').firstMatch(url);
  return m?.group(0) ?? 'restaurant-1';
}

Future<void> _loadAssets() async {
  final jakarta = FontLoader('PlusJakartaSans');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/PlusJakartaSans-$w.ttf').readAsBytesSync();
    jakarta.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await jakarta.load();

  final icons = FontLoader('MaterialIcons');
  icons.addFont(Future.value(ByteData.view(File('$_sdkFonts/materialicons-regular.otf').readAsBytesSync().buffer)));
  await icons.load();

  for (final f in Directory('../wwwroot/images/fallback').listSync().whereType<File>()) {
    _images[_imageKey(f.path)] = MemoryImage(f.readAsBytesSync());
  }
  // Ô tile trống màu nền bản đồ khi chưa có ảnh tile cục bộ
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = const Color(0xFFEDEAE2));
  final img = await recorder.endRecording().toImage(8, 8);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  _blankTile = MemoryImage(png!.buffer.asUint8List());
}

Future<void> _precache(Iterable<ImageProvider> providers) async {
  for (final p in providers) {
    final completer = Completer<void>();
    final stream = p.resolve(ImageConfiguration.empty);
    late final ImageStreamListener l;
    l = ImageStreamListener((_, __) {
      if (!completer.isCompleted) completer.complete();
      stream.removeListener(l);
    }, onError: (_, __) {
      if (!completer.isCompleted) completer.complete();
    });
    stream.addListener(l);
    await completer.future;
  }
}

// ---------------------------------------------------------------- harness

class _Env {
  final AuthProvider auth;
  final PlaceProvider places;
  final ShellController shell;
  _Env(this.auth, this.places, this.shell);
}

Future<_Env> _setup(WidgetTester tester, {bool loggedIn = false, bool loadPlaces = true, bool fail = false}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);

  FlutterSecureStorage.setMockInitialValues(loggedIn ? {ApiService.tokenKey: 'token'} : {});
  _adapter
    ..failAll = fail
    ..emptyChat = false;
  ApiService().dio.httpClientAdapter = _adapter;
  MapTiles.debugTileProvider = _LocalTileProvider();
  PlaceImage.debugImageBuilder = (url, fit) => Image(
        image: _images[_imageKey(url)]!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
      );

  final auth = AuthProvider(restoreSession: false);
  final places = PlaceProvider(autoLoad: false);
  await tester.runAsync(() async {
    await _precache([..._images.values, _blankTile]);
    if (loggedIn) await auth.checkCurrentUser();
    if (loadPlaces) await places.load();
  });
  // App mở vào tab Bản đồ; ảnh nào cần tab khác thì tự chuyển, mặc định của bộ ảnh là Khám phá
  return _Env(auth, places, ShellController()..go(ShellController.explore));
}

Future<void> _pumpApp(WidgetTester tester, _Env env, Widget home, {bool dark = false}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: env.auth),
          ChangeNotifierProvider.value(value: env.places),
          ChangeNotifierProvider.value(value: env.shell),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => RouteProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// Cho các Future thật (Dio giả, giải mã ảnh) chạy xong rồi dựng lại khung hình.
Future<void> _settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    // Khung đầu khởi động ticker, khung sau mới đẩy hoạt ảnh tới cuối
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    await _precache(_tileImages.values);
  });
  await tester.pump(const Duration(milliseconds: 50));
  await tester.runAsync(() async {
    final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void shotTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      // Tháo cây widget để huỷ timer/animation trước khi kiểm tra bất biến
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      debugDisableShadows = true;
    }
  });
}

PlaceModel _placeModel(int id) => PlaceModel.fromJson(fx.places.firstWhere((p) => p['id'] == id));

// ---------------------------------------------------------------- scenarios

void main() {
  group('Ảnh chụp màn hình', _scenarios,
      skip: _outDir.isEmpty ? 'Chạy với --dart-define=SHOTS_DIR=<thư mục> để chụp ảnh màn hình' : false);
}

void _scenarios() {
  setUpAll(_loadAssets);
  tearDownAll(() {
    if (_missingTiles.isNotEmpty) {
      File('$_outDir/missing_tiles.txt').writeAsStringSync(_missingTiles.join('\n'));
    }
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    shotTest('explore $mode', (tester) async {
      final env = await _setup(tester);
      await _pumpApp(tester, env, const MainShell(), dark: dark);
      await _shot(tester, '01_explore_$mode');
    });

    shotTest('detail $mode', (tester) async {
      final env = await _setup(tester, loggedIn: true);
      await _pumpApp(tester, env, PlaceDetailScreen(placeId: 1, preview: _placeModel(1)), dark: dark);
      await _shot(tester, '10_detail_top_$mode');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -620));
      await _settle(tester, rounds: 2);
      await _shot(tester, '11_detail_info_$mode');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await _settle(tester, rounds: 2);
      await _shot(tester, '12_detail_ai_$mode');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await _settle(tester, rounds: 2);
      await _shot(tester, '13_detail_reviews_$mode');
    });

    shotTest('chat $mode', (tester) async {
      final env = await _setup(tester, loggedIn: true);
      final place = PlaceModel.fromJson(fx.placeDetail(1));
      await _pumpApp(
        tester,
        env,
        ChatScreen(placeId: 1, placeName: place.name, receiverId: 'owner-1', place: place),
        dark: dark,
      );
      await _shot(tester, '30_chat_$mode');
    });

    shotTest('account user $mode', (tester) async {
      final env = await _setup(tester, loggedIn: true);
      env.shell.go(ShellController.account);
      await _pumpApp(tester, env, const MainShell(), dark: dark);
      await _shot(tester, '41_account_user_$mode');
    });

    shotTest('map $mode', (tester) async {
      final env = await _setup(tester);
      env.shell.go(ShellController.map);
      await _pumpApp(tester, env, const MainShell(), dark: dark);
      final pins = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MapPin');
      await tester.tap(pins.at(2), warnIfMissed: false);
      await _settle(tester);
      await _shot(tester, '05_map_selected_$mode');
    });
  }

  shotTest('explore logged in + scrolled', (tester) async {
    final env = await _setup(tester, loggedIn: true);
    await _pumpApp(tester, env, const MainShell());
    await _shot(tester, '02_explore_user_light');
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -520));
    await _settle(tester, rounds: 2);
    await _shot(tester, '03_explore_scrolled_light');
  });

  shotTest('explore search without diacritics', (tester) async {
    final env = await _setup(tester);
    await _pumpApp(tester, env, const MainShell());
    await tester.enterText(find.byType(TextField).first, 'com tam');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester, rounds: 1);
    await _shot(tester, '04_explore_search_light');
    await tester.enterText(find.byType(TextField).first, 'pizza');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester, rounds: 1);
    await _shot(tester, '04b_explore_search_empty_light');
  });

  shotTest('explore loading', (tester) async {
    final env = await _setup(tester, loadPlaces: false);
    await _pumpApp(tester, env, const MainShell());
    await _shot(tester, '06_explore_loading_light');
  });

  shotTest('explore error', (tester) async {
    final env = await _setup(tester, fail: true);
    await _pumpApp(tester, env, const MainShell());
    await _shot(tester, '07_explore_error_light');
  });

  shotTest('map filtered', (tester) async {
    final env = await _setup(tester);
    env.shell.go(ShellController.map);
    env.places.toggleCategory(2);
    await _pumpApp(tester, env, const MainShell());
    await _shot(tester, '08_map_filtered_light');
  });

  shotTest('review composer', (tester) async {
    final env = await _setup(tester, loggedIn: true);
    final place = _placeModel(1);
    await _pumpApp(tester, env, PlaceDetailScreen(placeId: 1, preview: place));
    final ctx = tester.element(find.byType(CustomScrollView));
    unawaited(showReviewComposer(ctx, place: place));
    await _settle(tester, rounds: 2);
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
    await tester.enterText(find.byType(TextField).last, 'Nước dùng ngon, phục vụ nhanh. Sẽ quay lại!');
    await _settle(tester, rounds: 2);
    await _shot(tester, '20_review_sheet_light');
  });

  shotTest('login', (tester) async {
    final env = await _setup(tester);
    await _pumpApp(tester, env, const LoginScreen(message: 'Đăng nhập để chia sẻ đánh giá của bạn.'));
    await _shot(tester, '50_login_light');
  });

  shotTest('login dark', (tester) async {
    final env = await _setup(tester);
    await _pumpApp(tester, env, const LoginScreen(), dark: true);
    await _shot(tester, '50_login_dark');
  });

  shotTest('register', (tester) async {
    final env = await _setup(tester);
    await _pumpApp(tester, env, const RegisterScreen());
    await tester.enterText(find.byType(TextFormField).at(1), 'Matkhau1');
    await _settle(tester, rounds: 1);
    await _shot(tester, '51_register_light');
  });

  shotTest('otp', (tester) async {
    final env = await _setup(tester);
    await _pumpApp(tester, env, const OtpScreen(email: 'minh.nguyen@gmail.com'));
    await tester.enterText(find.byType(TextField), '482');
    await _settle(tester, rounds: 1);
    await _shot(tester, '52_otp_light');
  });

  shotTest('account guest', (tester) async {
    final env = await _setup(tester);
    env.shell.go(ShellController.account);
    await _pumpApp(tester, env, const MainShell());
    await _shot(tester, '40_account_guest_light');
  });

  shotTest('account owner', (tester) async {
    _currentUser = fx.owner;
    addTearDown(() => _currentUser = fx.customer);
    final env = await _setup(tester, loggedIn: true);
    env.shell.go(ShellController.account);
    await _pumpApp(tester, env, const MainShell());
    await _shot(tester, '42_account_owner_light');
  });

  shotTest('chat empty', (tester) async {
    final env = await _setup(tester, loggedIn: true);
    _adapter.emptyChat = true;
    final place = PlaceModel.fromJson(fx.placeDetail(1));
    await _pumpApp(tester, env, ChatScreen(placeId: 1, placeName: place.name, receiverId: 'owner-1', place: place));
    await _shot(tester, '31_chat_empty_light');
  });
}
