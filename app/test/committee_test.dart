import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/data/building/committee_repository.dart';
import 'package:shacheni_app/features/building/building_app.dart';
import 'package:shacheni_app/features/building/committee_screen.dart';
import 'package:shacheni_app/features/building/glass_widgets.dart';

/// A committee repository whose caller can switch between committee and resident.
class Committee {
  bool admin = true;
  late final repo = LocalCommitteeRepository(
    apartmentFor: (_) => '12',
    isAdminFor: (_) => admin,
  );
}

const links = CommitteeSettings(
  monthlyAmount: 150,
  monthlyDueDay: 10,
  bitLink: 'https://www.bitpay.co.il/app/me/abc',
  payboxLink: 'https://link.payboxapp.com/xyz',
  cashNote: 'לרונית מדירה 4',
);

Widget committeeHarness(
  CommitteeRepository repo, {
  double scale = 1,
  Future<bool> Function(Uri)? openLink,
  Size? size,
}) => MaterialApp(
  locale: const Locale('he'),
  supportedLocales: const [Locale('he')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildingTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: SafeArea(
      child: CommitteeScreen(
        repository: repo,
        buildingId: 'b',
        apartment: '12',
        openLink: openLink,
      ),
    ),
  ),
);

Future<void> tapSave(WidgetTester tester, String key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final save = find.byKey(Key(key));
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  group('local committee', () {
    test(
      'the monthly fee opens itself once a month and follows the amount',
      () async {
        final c = Committee();
        await c.repo.load('b');
        await c.repo.saveSettings('b', links);
        var s = await c.repo.load('b');
        expect(s.isCommittee, isTrue);
        expect(s.charges.single.monthly, isTrue);
        expect(s.charges.single.amount, 150);
        s = await c.repo.load('b');
        expect(s.charges, hasLength(1));
        await c.repo.saveSettings(
          'b',
          const CommitteeSettings(monthlyAmount: 180, monthlyDueDay: 5),
        );
        expect((await c.repo.load('b')).charges.single.amount, 180);
      },
    );

    test('residents see only their own apartment and the totals', () async {
      final c = Committee();
      await c.repo.load('b');
      await c.repo.addCharge(
        'b',
        title: 'תיקון דלת',
        notes: '',
        amount: 200,
        dueOn: DateTime.now().add(const Duration(days: 7)),
      );
      final id = (await c.repo.load('b')).charges.single.id;
      await c.repo.markPaid(id, 'apt-2', true, method: 'cash');
      c.admin = false;
      final s = await c.repo.load('b');
      final charge = s.charges.single;
      expect(s.isCommittee, isFalse);
      expect(charge.apartments, isEmpty);
      expect(s.members, isEmpty);
      expect((charge.paid, charge.households), (1, 3));
      await expectLater(
        c.repo.addCharge(
          'b',
          title: 'x',
          notes: '',
          amount: 1,
          dueOn: DateTime.now(),
        ),
        throwsStateError,
      );
      await c.repo.reportPaid(id, 'bit');
      expect((await c.repo.load('b')).charges.single.myStatus, 'reported');
    });
  });

  test('remote adapter calls the committee endpoints', () async {
    final calls = <http.Request>[];
    final client = SupabaseClient(
      'https://committee.example.test',
      'publishable-test',
      httpClient: MockClient((r) async {
        calls.add(r);
        return http.Response(
          r.url.path.endsWith('ba_committee')
              ? jsonEncode({
                  'is_committee': true,
                  'committee': ['ליאב'],
                  'members': [],
                  'settings': {'monthly_amount': 150, 'bit_link': 'https://b'},
                  'charges': [
                    {
                      'id': 'c1',
                      'kind': 'monthly',
                      'title': 'דמי ועד',
                      'amount': 150,
                      'due_on': '2026-11-10',
                      'period': '2026-11-01',
                      'my_status': 'reported',
                      'paid': 3,
                      'households': 8,
                      'apartments': [],
                    },
                  ],
                })
              : 'null',
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    addTearDown(client.dispose);
    final repo = SupabaseCommitteeRepository(client);
    final s = await repo.load('b');
    expect(s.charges.single.period, DateTime(2026, 11));
    expect(committeeTitle(s.charges.single), 'דמי ועד · נובמבר');
    await repo.addCharge(
      'b',
      title: 'דלת',
      notes: '',
      amount: 200,
      dueOn: DateTime(2026, 12, 15, 18),
    );
    await repo.reportPaid('c1', 'bit');
    await repo.markPaid('c1', 'a1', true, method: 'cash');
    expect(calls.map((r) => r.url.path.split('/').last), [
      'ba_committee',
      'ba_committee_charge',
      'ba_committee_report',
      'ba_committee_mark',
    ]);
    expect(jsonDecode(calls[1].body)['p_due'], '2026-12-15');
  });

  testWidgets('a resident pays with bit and says so in one tap', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = Committee();
    await c.repo.load('b');
    await c.repo.saveSettings('b', links);
    c.admin = false;
    final opened = <Uri>[];
    await tester.pumpWidget(
      committeeHarness(
        c.repo,
        openLink: (u) async {
          opened.add(u);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('committee-add')), findsNothing);
    final charge = (await c.repo.load('b')).charges.single;
    expect(find.textContaining('דמי ועד ·'), findsOneWidget);
    expect(find.text('0 מתוך 3 דירות שילמו'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('committee-bit-${charge.id}')));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'www.bitpay.co.il');
    await tester.tap(find.byKey(ValueKey('committee-paid-${charge.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('committee-method-bit')));
    await tester.pumpAndSettle();
    expect(find.text('ממתין לאישור הוועד'), findsOneWidget);
    expect(find.byKey(ValueKey('committee-paid-${charge.id}')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the committee opens a repair charge and confirms a payment', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = Committee();
    await tester.pumpWidget(committeeHarness(c.repo));
    await tester.pumpAndSettle();
    expect(find.text('מתחילים בדמי הוועד'), findsOneWidget);
    await tester.tap(find.byKey(const Key('committee-add')));
    await tester.pumpAndSettle();
    await tapSave(tester, 'charge-save');
    expect(find.text('יש לכתוב על מה החיוב'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('charge-title')), 'תיקון דלת');
    await tester.enterText(find.byKey(const Key('charge-amount')), '200');
    await tester.pumpAndSettle();
    expect(find.textContaining('כל דירה תשלם'), findsOneWidget);
    await tapSave(tester, 'charge-save');
    expect(find.text('תיקון דלת'), findsOneWidget);
    final charge = (await c.repo.load('b')).charges.single;

    // A neighbour reports; the committee sees it waiting and confirms.
    c.admin = false;
    await c.repo.reportPaid(charge.id, 'paybox');
    c.admin = true;
    await tester.drag(
      find.byKey(const Key('committee-list')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    final payments = find.byKey(ValueKey('committee-payments-${charge.id}'));
    await tester.ensureVisible(payments);
    await tester.tap(payments);
    await tester.pumpAndSettle();
    expect(find.text('ממתינים לאישור'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('committee-apartment-apt-12')));
    await tester.pumpAndSettle();
    final after = (await c.repo.load('b')).charges.single;
    expect(after.myStatus, 'confirmed');
    expect(after.paid, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the committee sets the monthly fee and payment links', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = Committee();
    await tester.pumpWidget(committeeHarness(c.repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('committee-settings')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('committee-monthly')), '150');
    await tester.enterText(find.byKey(const Key('committee-bit')), 'bit.ly/x');
    await tapSave(tester, 'committee-settings-save');
    expect(find.textContaining('https://'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('committee-bit')),
      'https://www.bitpay.co.il/app/me/abc',
    );
    await tapSave(tester, 'committee-settings-save');
    final s = await c.repo.load('b');
    expect(s.settings.monthlyAmount, 150);
    expect(s.charges.single.monthly, isTrue);
    expect(find.textContaining('דמי ועד ·'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('committee page stays usable with large text on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = Committee();
    await c.repo.load('b');
    await c.repo.saveSettings('b', links);
    await tester.pumpWidget(committeeHarness(c.repo, scale: 1.5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('committee-settings')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the committee tab opens the committee page', (tester) async {
    final vm = BuildingViewModel(LocalBuildingRepository())..enter();
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildingTheme(),
        home: BuildingExperience(viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-3')));
    await tester.pumpAndSettle();
    expect(find.byType(CommitteeScreen), findsOneWidget);
    expect(find.text('ועד הבית'), findsWidgets);
  });
}
