import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/campaigns_page.dart';
import '../pages/challenges_page.dart';
import '../pages/impact_page.dart';
import '../pages/insights_page.dart';
import '../pages/issues_page.dart';
import '../pages/login_page.dart';
import '../pages/moderation_page.dart';
import '../pages/orgs_page.dart';
import '../pages/overview_page.dart';
import '../pages/places_page.dart';
import '../pages/points_page.dart';
import '../pages/users_page.dart';
import '../pages/verification_page.dart';
import '../pages/rewards_page.dart';
import '../pages/activities_page.dart';
import '../pages/pickups_page.dart';
import '../pages/events_page.dart';
import '../pages/public_site_page.dart';
import '../pages/enquiries_page.dart';
import '../pages/checkpoints_page.dart';
import '../pages/growth_pages.dart';
import '../widgets/shell.dart';
import 'session.dart';

const publicPaths = {'/for-organisations', '/pay/success', '/pay/cancelled'};

NoTransitionPage<void> _page(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

final GoRouter adminRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: Session.instance,
  redirect: (context, state) {
    final session = Session.instance;
    if (session.restoring) return null;
    // Public pages: open to everyone, signed in or not.
    if (publicPaths.contains(state.matchedLocation) || state.matchedLocation.startsWith('/verify/') || state.matchedLocation.startsWith('/esg/') || state.matchedLocation.startsWith('/join/')) return null;
    final atLogin = state.matchedLocation == '/login';
    if (!session.signedIn) return atLogin ? null : '/login';
    if (atLogin) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', pageBuilder: (context, state) => _page(state, const LoginPage())),
    GoRoute(path: '/for-organisations', pageBuilder: (context, state) => _page(state, const PublicSitePage())),
    GoRoute(path: '/esg/:token', pageBuilder: (context, state) => _page(state, EsgReportPage(token: state.pathParameters['token'] ?? ''))),
    GoRoute(path: '/verify/:code', pageBuilder: (context, state) => _page(state, VerifyCertificatePage(code: state.pathParameters['code'] ?? ''))),
    GoRoute(path: '/join/:code', pageBuilder: (context, state) => _page(state, JoinInvitePage(code: state.pathParameters['code'] ?? ''))),
    GoRoute(path: '/pay/success', pageBuilder: (context, state) => _page(state, const PaymentResultPage(success: true))),
    GoRoute(path: '/pay/cancelled', pageBuilder: (context, state) => _page(state, const PaymentResultPage(success: false))),
    ShellRoute(
      builder: (context, state, child) => AdminShell(location: state.matchedLocation, child: child),
      routes: [
        GoRoute(path: '/', pageBuilder: (context, state) => _page(state, const OverviewPage())),
        GoRoute(path: '/campaigns', pageBuilder: (context, state) => _page(state, const CampaignsPage())),
        GoRoute(path: '/verification', pageBuilder: (context, state) => _page(state, const VerificationPage())),
        GoRoute(path: '/points', pageBuilder: (context, state) => _page(state, const PointsPage())),
        GoRoute(path: '/issues', pageBuilder: (context, state) => _page(state, const IssuesPage())),
        GoRoute(path: '/checkpoints', pageBuilder: (context, state) => _page(state, const CheckpointsPage())),
        GoRoute(path: '/places', pageBuilder: (context, state) => _page(state, const PlacesPage())),
        GoRoute(path: '/activities', pageBuilder: (context, state) => _page(state, const ActivitiesPage())),
        GoRoute(path: '/sponsored', pageBuilder: (context, state) => _page(state, const SponsoredPage())),
        GoRoute(path: '/badges', pageBuilder: (context, state) => _page(state, const BadgesPage())),
        GoRoute(path: '/rewards', pageBuilder: (context, state) => _page(state, const RewardsPage())),
        GoRoute(path: '/pickups', pageBuilder: (context, state) => _page(state, const PickupsPage())),
        GoRoute(path: '/events', pageBuilder: (context, state) => _page(state, const EventsPage())),
        GoRoute(path: '/insights', pageBuilder: (context, state) => _page(state, const InsightsPage())),
        GoRoute(path: '/impact', pageBuilder: (context, state) => _page(state, const ImpactPage())),
        GoRoute(path: '/enquiries', pageBuilder: (context, state) => _page(state, const EnquiriesPage())),
        GoRoute(path: '/orgs', pageBuilder: (context, state) => _page(state, const OrgsPage())),
        GoRoute(path: '/users', pageBuilder: (context, state) => _page(state, const UsersPage())),
        GoRoute(path: '/moderation', pageBuilder: (context, state) => _page(state, const ModerationPage())),
        GoRoute(path: '/challenges', pageBuilder: (context, state) => _page(state, const ChallengesPage())),
      ],
    ),
  ],
);
