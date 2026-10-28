import 'package:go_router/go_router.dart';

import 'app_routes.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/navigation/presentation/screens/bottom_nav_screen.dart';
import '../../features/profile/presentation/screens/complete_profile_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (_, _) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const BottomNavScreen(),
      ),
    ],
  );
}
