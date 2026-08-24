import 'package:go_router/go_router.dart';

import 'app_routes.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/navigation/presentation/screens/bottom_nav_screen.dart';
import '../../features/profile/presentation/screens/complete_profile_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: AppRoutes.splash,

    routes: [

      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),

      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),

    
     GoRoute(
  path: "/complete-profile",
  builder: (context,state) =>
      const CompleteProfileScreen(),
),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const BottomNavScreen(),
      ),

    ],
  );
}