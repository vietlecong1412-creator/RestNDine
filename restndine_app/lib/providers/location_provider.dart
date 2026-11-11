import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Lý do không lấy được vị trí, để màn hình hướng dẫn người dùng xử lý.
enum LocationIssue {
  /// Định vị (GPS) của máy đang tắt.
  serviceDisabled,

  /// Người dùng vừa từ chối quyền; lần sau bấm sẽ hỏi lại.
  denied,

  /// Đã chặn hẳn ("Không hỏi lại"): chỉ bật lại được trong Cài đặt của app.
  deniedForever,

  /// Có quyền nhưng không bắt được tín hiệu kịp.
  unavailable,
}

/// Vị trí của người dùng, dùng chung cho cả app: tab Khám phá xếp quán gần nhất lên đầu,
/// tab Bản đồ hiện chấm xanh và nút "Vị trí của tôi".
///
/// Chỉ xin quyền khi người dùng chủ động bấm ([locate]); đã cấp từ trước thì [resumeIfPermitted]
/// tự lấy vị trí lúc mở app mà không hỏi lại. Ngừng theo dõi khi app chạy nền để tiết kiệm pin.
class LocationProvider extends ChangeNotifier with WidgetsBindingObserver {
  /// Vị trí hệ thống lưu từ trước chỉ dùng nếu còn mới; vị trí cũ (hôm qua, thành phố khác)
  /// sẽ làm camera và thứ tự "gần nhất" sai hẳn.
  static const _maxLastKnownAge = Duration(minutes: 2);

  /// Lúc mở app chỉ cần đủ để xếp danh sách ngay; luồng theo dõi sẽ chỉnh lại sau vài giây.
  static const _maxResumeAge = Duration(minutes: 10);

  LatLng? _position;
  bool _locating = false;
  StreamSubscription<Position>? _updates;

  LocationProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Vị trí gần nhất đã biết; null khi chưa có quyền hoặc chưa định vị được.
  LatLng? get position => _position;

  /// Đang chờ hệ thống trả vị trí (hiện vòng xoay trên nút).
  bool get locating => _locating;

  /// Xin quyền nếu cần rồi trả về vị trí hiện tại. Ném [LocationIssue] khi không được;
  /// trả về null nếu lần bấm trước vẫn đang chờ.
  Future<LatLng?> locate() async {
    if (_locating) return null;
    _locating = true;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw LocationIssue.serviceDisabled;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) throw LocationIssue.deniedForever;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        throw LocationIssue.denied;
      }
      final last = await Geolocator.getLastKnownPosition();
      final fresh = last != null && DateTime.now().difference(last.timestamp) < _maxLastKnownAge;
      final pos = fresh
          ? last
          : await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 15),
              ),
            );
      _position = LatLng(pos.latitude, pos.longitude);
      _listen();
      return _position;
    } on TimeoutException {
      throw LocationIssue.unavailable;
    } on LocationServiceDisabledException {
      throw LocationIssue.serviceDisabled;
    } finally {
      _locating = false;
      notifyListeners();
    }
  }

  bool _startedUp = false;

  /// Khi mở app: chưa cấp quyền thì hỏi luôn (app gợi ý quán gần bạn nên cần vị trí ngay từ đầu),
  /// đã cấp thì lấy vị trí. Bị từ chối, đã chặn hẳn hay GPS tắt thì im lặng: tab Khám phá có lời
  /// mời bật lại, nút trên bản đồ sẽ giải thích khi người dùng bấm. Hệ điều hành cũng tự giới hạn
  /// số lần hỏi (Android: từ chối 2 lần là thôi), nên không làm phiền ở các lần mở sau.
  Future<void> startup() async {
    if (_startedUp) return;
    _startedUp = true;
    try {
      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('Không hỏi được quyền vị trí: $e');
      return;
    }
    await resumeIfPermitted();
  }

  /// Đã cho quyền thì bắt đầu theo dõi vị trí, không hỏi gì cả (gọi lúc mở app và khi quay lại app).
  Future<void> resumeIfPermitted() async {
    if (_updates != null) return;
    try {
      final permission = await Geolocator.checkPermission();
      final permitted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (!permitted || !await Geolocator.isLocationServiceEnabled()) return;

      if (_position == null) {
        final last = await Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);
        if (last != null && DateTime.now().difference(last.timestamp) < _maxResumeAge) {
          _position = LatLng(last.latitude, last.longitude);
          notifyListeners();
        }
      }
      _listen();
    } catch (e) {
      // Không có plugin (test, nền tảng chưa hỗ trợ) thì app chạy như chưa có vị trí
      debugPrint('Không đọc được quyền vị trí: $e');
    }
  }

  /// Theo dõi khi đang mở app. Trên Android đi qua LocationManager của hệ thống: Google Play
  /// Services sẽ bật hộp thoại "Location Accuracy" ngay lúc mở app, hộp thoại đó chỉ nên hiện
  /// khi người dùng tự bấm nút định vị. Phải xin độ chính xác cao: mức thấp hơn chỉ dùng định vị
  /// mạng, máy tắt "Location Accuracy" sẽ không bao giờ có vị trí. Cách 5 giây một lần cho đỡ tốn pin.
  static LocationSettings get _trackingSettings => defaultTargetPlatform == TargetPlatform.android
      ? AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          intervalDuration: const Duration(seconds: 5),
          forceLocationManager: true,
        )
      : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);

  void _listen() {
    _updates ??= Geolocator.getPositionStream(
      // Chỉ báo khi đi được 10 m để không sắp xếp/vẽ lại liên tục
      locationSettings: _trackingSettings,
    ).listen(
      (pos) {
        _position = LatLng(pos.latitude, pos.longitude);
        notifyListeners();
      },
      // Tắt GPS giữa chừng: giữ vị trí cuối, bấm nút sẽ báo lỗi cụ thể
      onError: (Object e) => debugPrint('Mất tín hiệu vị trí: $e'),
    );
  }

  void _stopListening() {
    _updates?.cancel();
    _updates = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quyền "khi đang dùng app": chạy nền thì ngừng GPS. Quay lại thì kiểm tra lại quyền,
    // vì người dùng có thể vừa bật/tắt trong Cài đặt (từ nút "Cài đặt" trên thông báo lỗi)
    if (state == AppLifecycleState.paused) {
      _stopListening();
    } else if (state == AppLifecycleState.resumed) {
      resumeIfPermitted();
    }
  }

  /// Mở đúng trang Cài đặt để người dùng tự sửa [issue].
  static Future<void> openSettingsFor(LocationIssue issue) => issue == LocationIssue.serviceDisabled
      ? Geolocator.openLocationSettings()
      : Geolocator.openAppSettings();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopListening();
    super.dispose();
  }
}
