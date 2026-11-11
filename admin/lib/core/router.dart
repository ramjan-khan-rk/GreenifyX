import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/campaigns_page.dart';
import '../pages/challenges_page.dart';
import '../pages/impact_page.dart';
import '../pages/login_page.dart';
import '../pages/moderation_page.dart';
import '../pages/overview_page.dart';
import '../pages/points_page.dart';
import '../pages/users_page.dart';
import '../pages/verification_page.dart';
import '../widgets/shell.dart';
import 'session.dart';

NoTransitionPage<void> _page(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

final GoRouter adminRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: Session.instance,
  redirect: (context, state) {
    final session = Session.instance;
    if (session.restoring) return null;
    final atLogin = state.matchedLocation == '/login';
    if (!session.signedIn) return atLogin ? null : '/login';
    if (atLogin) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', pageBuilder: (context, state) => _page(state, const LoginPage())),
    ShellRoute(
      builder: (context, state, child) => AdminShell(location: state.matchedLocation, child: child),
      routes: [
        GoRoute(path: '/', pageBuilder: (context, state) => _page(state, const OverviewPage())),
        GoRoute(path: '/campaigns', pageBuilder: (context, state) => _page(state, const CampaignsPage())),
        GoRoute(path: '/verification', pageBuilder: (context, state) => _page(state, const VerificationPage())),
        GoRoute(path: '/points', pageBuilder: (context, state) => _page(state, const PointsPage())),
        GoRoute(path: '/impact', pageBuilder: (context, state) => _page(state, const ImpactPage())),
        GoRoute(path: '/users', pageBuilder: (context, state) => _page(state, const UsersPage())),
        GoRoute(path: '/moderation', pageBuilder: (context, state) => _page(state, const ModerationPage())),
        GoRoute(path: '/challenges', pageBuilder: (context, state) => _page(state, const ChallengesPage())),
      ],
    ),
  ],
);
