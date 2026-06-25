import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'config/theme.dart';
import 'providers/incidente_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cumplimiento_provider.dart';
import 'providers/peligro_provider.dart';
import 'providers/theme_provider.dart';
import 'services/peligros_service.dart';
import 'services/supabase_setup_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabasePublishableKey,
  );

  // Auto-configurar tablas y bucket de Supabase si no existen
  await SupabaseSetupService.ensureSetup();

  runApp(const ProReportApp());
}

class ProReportApp extends StatelessWidget {
  const ProReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const _ProReportAppWithTheme(),
    );
  }
}

class _ProReportAppWithTheme extends StatefulWidget {
  const _ProReportAppWithTheme();

  @override
  State<_ProReportAppWithTheme> createState() => _ProReportAppWithThemeState();
}

class _ProReportAppWithThemeState extends State<_ProReportAppWithTheme> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ThemeProvider>().loadPreference();
    });
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final themeProvider = context.watch<ThemeProvider>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              IncidenteProvider(client)
                ..loadCatalogos(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(client),
        ),
        ChangeNotifierProvider(
          create: (_) => CumplimientoProvider(client),
        ),
        ChangeNotifierProvider(
          create: (_) => PeligroProvider(PeligrosService(client: client)),
        ),
      ],
      child: MaterialApp(
        title: 'PROreport',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.themeMode,
        home: const _AuthenticationGate(),
      ),
    );
  }
}

/// Widget que verifica si hay una sesión activa
/// Si hay sesión, va al home; si no, va al login
class _AuthenticationGate extends StatelessWidget {
  const _AuthenticationGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isAuthenticated) {
      return const HseDashboardScreen();
    } else {
      return const LoginScreen();
    }
  }
}