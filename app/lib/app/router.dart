import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../features/access/access_screens.dart';
import '../features/admin/admin_screens.dart';
import '../features/common/profile_notifications.dart';
import '../features/home/home_screen.dart';
import '../features/me/me_screens.dart';
import '../features/money/transactions_screens.dart';
import '../features/packages/door_delivery.dart';
import '../features/packages/packages_screens.dart';
import '../features/parking/parking_screens.dart';
import '../features/platform/platform_screens.dart';
import '../features/shell/main_shell.dart';

/// Routing gate (architecture doc "App routing gates"): the access stage decides which
/// screens are reachable; an approved resident never sees the access screens again.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(demoProvider, (_, _) => refresh.value++);
  ref.listen(gateProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  const accessPaths = {'/welcome', '/phone', '/otp', '/legal', '/join', '/apply', '/pending'};

  GoRoute simple(String path, Widget Function(GoRouterState s) build) =>
      GoRoute(path: path, builder: (context, state) => build(state));

  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: refresh,
    redirect: (context, state) {
      var stage = ref.read(demoProvider).data.stage;
      final loc = state.matchedLocation;
      // Real backend: sign-in and consent are decided by Supabase; the steps after them
      // (join → apply → pending → approved) still come from the demo store for now.
      switch (ref.read(gateProvider)) {
        case Gate.demo:
          break;
        case Gate.loading:
          return loc == '/loading' ? null : '/loading';
        case Gate.signedOut:
          if (loc.startsWith('/doc/')) return null;
          return loc == '/welcome' ? null : '/welcome';
        case Gate.consent:
          if (loc.startsWith('/doc/')) return null;
          return loc == '/legal' ? null : '/legal';
        case Gate.ready:
          if (stage.index < AuthStage.join.index) stage = AuthStage.join;
      }
      if (stage == AuthStage.approved) {
        return accessPaths.contains(loc) ? '/home' : null;
      }
      if (loc.startsWith('/doc/')) return null;
      final target = '/${stage.name}';
      return loc == target ? null : target;
    },
    routes: [
      simple('/loading', (_) => const LoadingScreen()),
      simple('/welcome', (_) => const WelcomeScreen()),
      simple('/phone', (_) => const PhoneScreen()),
      simple('/otp', (_) => const OtpScreen()),
      simple('/legal', (_) => const LegalConsentScreen()),
      simple('/join', (_) => const JoinScreen()),
      simple('/apply', (_) => const ApplyScreen()),
      simple('/pending', (_) => const PendingScreen()),
      simple('/doc/:type', (s) => LegalDocScreen(type: s.pathParameters['type']!)),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [simple('/home', (_) => const HomeScreen())]),
          StatefulShellBranch(routes: [simple('/parking', (_) => const ParkingScreen())]),
          StatefulShellBranch(routes: [simple('/packages', (_) => const PackagesScreen())]),
          StatefulShellBranch(routes: [simple('/me', (_) => const MeScreen())]),
        ],
      ),
      simple('/notifications', (_) => const NotificationsScreen()),
      // Parking
      simple('/parking/listing/:id', (s) => ListingDetailScreen(id: s.pathParameters['id']!)),
      simple('/parking/my-listing/:id', (s) => MyListingScreen(id: s.pathParameters['id']!)),
      simple('/parking/publish', (_) => const PublishParkingScreen()),
      simple('/parking/reservation/:id', (s) => ReservationScreen(id: s.pathParameters['id']!)),
      simple('/parking/spaces', (_) => const MySpacesScreen()),
      simple('/parking/spaces/request', (_) => const RequestAssignmentScreen()),
      // Packages
      simple('/packages/new', (_) => const NewRequestScreen()),
      simple('/packages/request/:id', (s) => RequestDetailScreen(id: s.pathParameters['id']!)),
      simple('/packages/request/:id/code', (s) => CodeEntryScreen(id: s.pathParameters['id']!)),
      simple('/packages/request/:id/door', (s) => DoorPhotoScreen(id: s.pathParameters['id']!)),
      simple('/packages/request/:id/photo', (s) => PhotoViewerScreen(id: s.pathParameters['id']!)),
      // Money / profile
      simple('/transaction/:id', (s) => TransactionScreen(id: s.pathParameters['id']!)),
      simple('/history', (_) => const HistoryScreen()),
      simple('/profile/:id', (s) => NeighborProfileScreen(personId: s.pathParameters['id']!)),
      simple('/settings', (_) => const SettingsScreen()),
      simple('/me/edit', (_) => const EditProfileScreen()),
      // Building admin
      simple('/admin', (_) => const AdminDashboardScreen()),
      simple('/admin/applications', (_) => const ApplicationsScreen()),
      simple('/admin/applications/:id', (s) => ApplicationReviewScreen(id: s.pathParameters['id']!)),
      simple('/admin/assignments', (_) => const AssignmentsAdminScreen()),
      simple('/admin/disputes', (_) => const DisputesScreen()),
      simple('/admin/stats', (_) => const StatsScreen()),
      simple('/admin/activity', (_) => const ActivityScreen()),
      simple('/admin/residents', (_) => const ResidentsScreen()),
      simple('/admin/apartments', (_) => const BuildingListScreen(spaces: false)),
      simple('/admin/spaces', (_) => const BuildingListScreen(spaces: true)),
      simple('/admin/settings', (_) => const BuildingSettingsScreen()),
      // Platform admin
      simple('/platform', (_) => const PlatformScreen()),
      simple('/platform/create', (_) => const CreateBuildingScreen()),
    ],
  );
});

