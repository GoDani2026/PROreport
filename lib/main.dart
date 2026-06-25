import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'config/theme.dart';
import 'providers/incidente_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cumplimiento_provider.dart';
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
    final client = Supabase.instance.client;

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
      ],
      child: MaterialApp(
        title: 'PROreport',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
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