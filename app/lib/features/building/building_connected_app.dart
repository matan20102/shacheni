import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/appearance.dart';
import '../../app/config.dart';
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
  static const _pendingJoinKey = 'naybor.pending_join_code';
  String? joinCode = joinCodeFromLink(Uri.base);

  // Google sign-in returns to the bare origin, so the code waits on the device.
  Future<void> _rememberJoinCode() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final linked = joinCode;
      if (linked != null) {
        await preferences.setString(_pendingJoinKey, linked);
      } else {
        final saved = preferences.getString(_pendingJoinKey);
        if (saved != null && mounted) setState(() => joinCode = saved);
      }
    } catch (_) {
      /* An invitation link is a convenience; the code can still be typed. */
    }
  }

  Future<void> _forgetJoinCode() async {
    joinCode = null;
    try {
      await (await SharedPreferences.getInstance()).remove(_pendingJoinKey);
    } catch (_) {
      /* Nothing was stored. */
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_rememberJoinCode());
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
          SupabaseBuildingRepository(client, realtime: widget.client == null),
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
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: appearance,
    builder: (context, mode, _) => MaterialApp(
      navigatorKey: navigator,
      title: '$appNameHebrew · $appNameEnglish',
      debugShowCheckedModeBanner: false,
      theme: buildingTheme(),
      darkTheme: buildingTheme(Brightness.dark),
      themeMode: mode,
      locale: const Locale('he'),
      supportedLocales: const [Locale('he')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: loading
          ? const GlassBackground(
              child: Scaffold(body: SkeletonPage(label: 'טוענים את הבניין…')),
            )
          : error != null
          ? GlassBackground(
              child: Scaffold(
                body: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(Space.xxl),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: StateMessage(
                        icon: Icons.cloud_off_outlined,
                        title: 'משהו השתבש',
                        text: error!,
                        error: true,
                        action: Column(
                          children: [
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
              initialJoinCode: joinCode,
              onJoinCodeUsed: () => unawaited(_forgetJoinCode()),
            ),
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
                const SizedBox(height: Space.xxxl),
                Text(
                  'בית אחד.\nהרבה שכנים טובים.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: Space.l),
                Text(
                  'כל מה שקורה בבניין, במקום אחד פשוט.\nלהתעדכן, לעזור ולנהל את הבית יחד.',
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.7,
                    color: context.glass.muted,
                  ),
                ),
                const SizedBox(height: Space.xxxl),
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
                      style: TextStyle(color: context.glass.error),
                    ),
                  ),
                const SizedBox(height: Space.l),
                Text(
                  'מצטרפים עם קוד בניין, או יוצרים בית חדש ב$appNameHebrew.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.glass.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
