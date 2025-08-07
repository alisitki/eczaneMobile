import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'pages/home_page.dart';

void main() async {
  // Widget binding'i başlat
  WidgetsFlutterBinding.ensureInitialized();

  // Sadece portrait (dikey) modu aktif et
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Debug modundaki sarı baseline çizgilerini kapat
  debugPaintBaselinesEnabled = false;
  debugPaintSizeEnabled = false;
  debugPaintPointersEnabled = false;

  runApp(const EczanePanosuApp());
}

class EczanePanosuApp extends StatelessWidget {
  const EczanePanosuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eczane Panosu',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E8B57), // Sea Green
          brightness: Brightness.dark, // Dark theme için
        ),
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}
