import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/place_provider.dart';
import 'screens/shell/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Font đóng gói kèm app (OFL) cần hiện trong mục "Giấy phép" của hộp thoại Giới thiệu
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Plus Jakarta Sans'], license);
  });
  runApp(const RestNDineApp());
}

class RestNDineApp extends StatelessWidget {
  const RestNDineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlaceProvider()),
        ChangeNotifierProvider(create: (_) => ShellController()),
      ],
      child: MaterialApp(
        title: 'RestNDine',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        // Chuỗi hệ thống (menu Sao chép/Dán, tooltip, hộp thoại) bằng tiếng Việt
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Vẫn tôn trọng cỡ chữ hệ thống nhưng chặn mức quá lớn làm vỡ bố cục
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
            ),
            child: child!,
          );
        },
        home: const MainShell(),
      ),
    );
  }
}
