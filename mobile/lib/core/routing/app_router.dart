import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../features/ai_assistant/ai_assistant_screen.dart';
import '../../features/assessments/assessments_screen.dart';
import '../../features/audit/audit_screen.dart';
import '../../features/authentication/login_screen.dart';
import '../../features/authentication/mfa_screen.dart';
import '../../features/authentication/session_gate_screen.dart';
import '../../features/authentication/splash_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/documents/documents_screen.dart';
import '../../features/evidence/evidence_screen.dart';
import '../../features/external_services/external_services_screen.dart';
import '../../features/obligations/obligations_screen.dart';
import '../../features/organizations/organization_create_screen.dart';
import '../../features/organizations/organization_selection_screen.dart';
import '../../features/questionnaires/questionnaire_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/scanner/scanner_screen.dart';
import '../../features/settings/more_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/websites/websites_screen.dart';
import '../auth/auth_state.dart';
import '../widgets/adaptive_shell.dart';
import 'organization_form_exit_guard.dart';
import 'questionnaire_exit_guard.dart';

final class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (Ref ref) => GlobalKey<NavigatorState>(),
);

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final RouterRefreshNotifier refresh = RouterRefreshNotifier();
  ref.listen<AuthState>(authControllerProvider, (_, _) => refresh.refresh());
  ref.listen(organizationControllerProvider, (_, _) => refresh.refresh());
  final GoRouter router = GoRouter(
    navigatorKey: ref.watch(rootNavigatorKeyProvider),
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final AuthState auth = ref.read(authControllerProvider);
      final String location = state.matchedLocation;
      return switch (auth.phase) {
        AuthPhase.checking => location == '/splash' ? null : '/splash',
        AuthPhase.signedOut => location == '/login' ? null : '/login',
        AuthPhase.mfaRequired => location == '/mfa' ? null : '/mfa',
        AuthPhase.locked ||
        AuthPhase.offline ||
        AuthPhase.blocked => location == '/session' ? null : '/session',
        AuthPhase.authenticated =>
          const <String>{
                '/splash',
                '/login',
                '/mfa',
                '/session',
              }.contains(location)
              ? '/organizations'
              : null,
      };
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) => _page(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _page(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/mfa',
        pageBuilder: (_, state) => _page(state, const MfaScreen()),
      ),
      GoRoute(
        path: '/session',
        pageBuilder: (_, state) => _page(state, const SessionGateScreen()),
      ),
      ShellRoute(
        builder: (_, state, child) =>
            AdaptiveShell(location: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/organizations',
            pageBuilder: (_, state) =>
                _page(state, const OrganizationSelectionScreen()),
            routes: [
              GoRoute(
                path: 'new',
                onExit: (_, _) async {
                  if (ref.read(authControllerProvider).phase !=
                      AuthPhase.authenticated) {
                    return true;
                  }
                  return await ref
                          .read(organizationFormExitGuardProvider)
                          .confirm
                          ?.call() ??
                      true;
                },
                pageBuilder: (_, state) =>
                    _page(state, const OrganizationCreateScreen()),
              ),
            ],
          ),
          GoRoute(
            path: '/dashboard',
            pageBuilder: (_, state) => _page(state, const DashboardScreen()),
          ),
          GoRoute(
            path: '/questionnaire',
            onExit: (_, _) async {
              if (ref.read(authControllerProvider).phase !=
                  AuthPhase.authenticated) {
                return true;
              }
              return await ref
                      .read(questionnaireExitGuardProvider)
                      .confirm
                      ?.call() ??
                  true;
            },
            pageBuilder: (_, state) =>
                _page(state, const QuestionnaireScreen()),
          ),
          GoRoute(
            path: '/obligations',
            pageBuilder: (_, state) => _page(state, const ObligationsScreen()),
          ),
          GoRoute(
            path: '/ai',
            pageBuilder: (_, state) => _page(state, const AiAssistantScreen()),
          ),
          GoRoute(
            path: '/more',
            pageBuilder: (_, state) => _page(state, const MoreScreen()),
          ),
          GoRoute(
            path: '/websites',
            pageBuilder: (_, state) => _page(state, const WebsitesScreen()),
          ),
          GoRoute(
            path: '/services',
            pageBuilder: (_, state) =>
                _page(state, const ExternalServicesScreen()),
          ),
          GoRoute(
            path: '/assessments',
            pageBuilder: (_, state) => _page(state, const AssessmentsScreen()),
          ),
          GoRoute(
            path: '/scanner',
            pageBuilder: (_, state) => _page(
              state,
              ScannerScreen(websiteId: state.uri.queryParameters['site']),
            ),
          ),
          GoRoute(
            path: '/documents',
            pageBuilder: (_, state) => _page(state, const DocumentsScreen()),
          ),
          GoRoute(
            path: '/evidence',
            pageBuilder: (_, state) => _page(state, const EvidenceScreen()),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (_, state) => _page(state, const ReportsScreen()),
          ),
          GoRoute(
            path: '/audit',
            pageBuilder: (_, state) => _page(state, const AuditScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (_, state) => _page(state, const SettingsScreen()),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

CustomTransitionPage<void> _page(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 7 / MediaQuery.sizeOf(context).height),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
