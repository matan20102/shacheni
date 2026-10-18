import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth.dart';
import '../../app/brand.dart';
import '../../data/building/building_repository.dart';
import '../../data/building/board_read_store.dart';
import '../../data/building/supabase_building_repository.dart';
import 'building_app.dart';
import 'building_consent_screen.dart';
import 'glass_widgets.dart';

class BuildingConnectedApp extends StatefulWidget {
  const BuildingConnectedApp({super.key, this.client, this.readStore});
  final SupabaseClient? client;
  final BoardReadStore? readStore;
  @override
  State<BuildingConnectedApp> createState() => _BuildingConnectedAppState();
}

class _BuildingConnectedAppState extends State<BuildingConnectedApp> {
  SupabaseClient get client => widget.client ?? Supabase.instance.client;
  late final auth = AuthRepository(client: client);
  final navigator = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? subscription;
  BuildingViewModel? vm;
  List<LegalDoc> documents = const [];
  String? error;
  bool loading = true;
  bool signedIn = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    subscription = client.auth.onAuthStateChange.listen(
      (state) {
        // The explicit refresh below already reads the initial session. Replaying
        // it used to start the entire consent/state/board chain twice at launch.
        if (state.event == AuthChangeEvent.initialSession ||
            state.event == AuthChangeEvent.tokenRefreshed) {
          return;
        }
        navigator.currentState?.popUntil((route) => route.isFirst);
        unawaited(refresh());
      },
      onError: (Object failure) {
        if (!mounted) return;
        setState(() {
          generation++;
          loading = false;
          error = buildingErrorMessage(failure);
        });
      },
    );
    unawaited(refresh());
  }

  @override
  void dispose() {
    generation++;
    subscription?.cancel();
    vm?.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final request = ++generation;
    final hasSession = client.auth.currentSession != null;
    setState(() {
      signedIn = hasSession;
      loading = true;
      error = null;
    });
    BuildingViewModel? next;
    try {
      final pending = hasSession ? await auth.pendingLegal('he') : <LegalDoc>[];
      if (!mounted || request != generation) return;
      if (hasSession && pending.isEmpty) {
        next = BuildingViewModel(
          SupabaseBuildingRepository(client),
          readStore:
              widget.readStore ??
              DeviceBoardReadStore(client.auth.currentUser!.id),
        );
        await next.initialize();
      }
      if (!mounted || request != generation) {
        next?.dispose();
        return;
      }
      final previous = vm;
      setState(() {
        vm = next;
        documents = pending;
        loading = false;
      });
      previous?.dispose();
    } catch (failure) {
      next?.dispose();
      if (!mounted || request != generation) return;
      setState(() {
        loading = false;
        error = buildingErrorMessage(failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigator,
    title: '$appNameHebrew · $appNameEnglish',
    debugShowCheckedModeBanner: false,
    theme: buildingTheme(),
    locale: const Locale('he'),
    supportedLocales: const [Locale('he')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: loading
        ? const GlassBackground(
            child: Scaffold(body: Center(child: CircularProgressIndicator())),
          )
        : error != null
        ? GlassBackground(
            child: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 56,
                        color: glassTeal,
                      ),
                      const SizedBox(height: 18),
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: refresh,
                        child: const Text('ניסיון נוסף'),
                      ),
                      if (signedIn)
                        TextButton(
                          onPressed: auth.signOut,
                          child: const Text('יציאה מהחשבון'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : !signedIn
        ? _GoogleWelcome(auth: auth)
        : documents.isNotEmpty
        ? BuildingConsentScreen(
            documents: documents,
            onAccept: (types) async {
              await auth.acceptLegal(types, 'he');
              await refresh();
            },
            onSignOut: auth.signOut,
          )
        : BuildingExperience(
            key: ObjectKey(vm),
            viewModel: vm,
            onSignOut: auth.signOut,
          ),
  );
}

class _GoogleWelcome extends StatefulWidget {
  const _GoogleWelcome({required this.auth});
  final AuthRepository auth;
  @override
  State<_GoogleWelcome> createState() => _GoogleWelcomeState();
}

class _GoogleWelcomeState extends State<_GoogleWelcome> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => GlassBackground(
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(28),
              children: [
                const Eyebrow(appNameEnglish),
                const SizedBox(height: 44),
                const Center(child: BuildingMark(size: 130)),
                const SizedBox(height: 32),
                Text(
                  'בית אחד.\nהרבה שכנים טובים.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),
                const Text(
                  'כל מה שקורה בבניין, במקום אחד פשוט.\nלהתעדכן, לעזור ולנהל את הבית יחד.',
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.7,
                    color: glassMuted,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await widget.auth.signInWithGoogle();
                          } catch (failure) {
                            if (mounted) {
                              setState(
                                () => error = buildingErrorMessage(failure),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  icon: const Icon(Icons.login_rounded),
                  label: Text(busy ? 'מתחברים…' : 'כניסה עם Google'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: glassError),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'מצטרפים עם קוד בניין, או יוצרים בית חדש ב$appNameHebrew.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: glassMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
