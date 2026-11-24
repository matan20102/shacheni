import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/committee_repository.dart';
import 'package:shacheni_app/data/building/inquiry_repository.dart';
import 'package:shacheni_app/features/building/committee_inquiries.dart';
import 'package:shacheni_app/features/building/committee_screen.dart';
import 'package:shacheni_app/features/building/glass_widgets.dart';

class Committee {
  bool admin = true;
  late final repo = LocalCommitteeRepository(
    apartmentFor: (_) => '12',
    isAdminFor: (_) => admin,
  );
  LocalInquiryRepository get inquiries => repo.inquiries;
}

Widget harness(CommitteeRepository repo) => MaterialApp(
  locale: const Locale('he'),
  supportedLocales: const [Locale('he')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildingTheme(),
  home: Scaffold(
    body: SafeArea(
      child: CommitteeScreen(
        repository: repo,
        buildingId: 'b',
        apartment: '12',
      ),
    ),
  ),
);

void main() {
  group('local inquiries', () {
    test('a conversation between a resident and the committee', () async {
      final c = Committee()..admin = false;
      final id = await c.inquiries.send('b', ' Leak ', ' Water on the stairs ');
      var l = await c.inquiries.list('b');
      expect(l.isCommittee, isFalse);
      expect(l.inbox, isEmpty);
      expect(l.mine.single.subject, 'Leak');
      expect(l.mine.single.unread, isFalse);
      await expectLater(
        c.inquiries.setHandled(id, true),
        throwsA(isA<StateError>()),
      );

      c.inquiries.answer(id, 'We called the plumber');
      l = await c.inquiries.list('b');
      expect(l.unread, 1);
      expect(l.mine.single.preview, 'We called the plumber');
      final th = await c.inquiries.open(id);
      expect(th.messages.map((m) => m.fromCommittee), [false, true]);
      expect((await c.inquiries.list('b')).unread, 0);
    });

    test(
      'the committee answers and marks handled; a new message reopens',
      () async {
        final c = Committee();
        final id = c.inquiries.receive('b', subject: 'Noise', body: 'At night');
        var l = await c.inquiries.list('b');
        expect(l.isCommittee, isTrue);
        expect(l.inbox.single.author, 'דנה לוי');
        expect(l.unread, 1);
        final th = await c.inquiries.open(id);
        expect(th.asCommittee, isTrue);
        await c.inquiries.reply(id, 'We will talk to them');
        await c.inquiries.setHandled(id, true);
        l = await c.inquiries.list('b');
        expect(l.inbox.single.handled, isTrue);
        expect(l.unread, 0);
        await expectLater(
          c.inquiries.send('b', '', 'x'),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  testWidgets('a resident writes privately to the committee', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = Committee()..admin = false;
    await tester.pumpWidget(harness(c.repo));
    await tester.pumpAndSettle();
    expect(find.text('פנייה פרטית לוועד'), findsOneWidget);

    await tester.tap(find.byKey(const Key('committee-inquiries')));
    await tester.pumpAndSettle();
    expect(find.text('עוד לא פנית לוועד'), findsOneWidget);

    await tester.tap(find.byKey(const Key('inquiry-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inquiry-send')));
    await tester.pumpAndSettle();
    expect(find.text('יש לכתוב נושא'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('inquiry-subject')), 'נזילה');
    await tester.enterText(
      find.byKey(const Key('inquiry-body')),
      'יש מים בחדר המדרגות בקומה 3',
    );
    await tester.tap(find.byKey(const Key('inquiry-send')));
    await tester.pumpAndSettle();
    expect(find.text('נזילה'), findsOneWidget);
    expect(find.text('יש מים בחדר המדרגות בקומה 3'), findsOneWidget);

    // The committee answers; the resident sees it marked new and reads it.
    final id = (await c.inquiries.list('b')).mine.single.id;
    c.inquiries.answer(id, 'שלחנו אינסטלטור');
    await tester.drag(
      find.byKey(const Key('inquiries-list')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('inquiry-$id')));
    await tester.pumpAndSettle();
    expect(find.text('שלחנו אינסטלטור'), findsOneWidget);
    expect(find.byKey(const Key('inquiry-handled')), findsNothing);
    await tester.enterText(find.byKey(const Key('inquiry-reply')), 'תודה!');
    await tester.tap(find.byKey(const Key('inquiry-reply-send')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('inquiry-messages')),
        matching: find.text('תודה!'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the committee answers and marks an inquiry handled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = Committee();
    final id = c.inquiries.receive(
      'b',
      subject: 'רעש בלילה',
      body: 'השכנים מלמעלה מרעישים אחרי חצות',
    );
    await tester.pumpWidget(harness(c.repo));
    await tester.pumpAndSettle();
    expect(find.text('פניות מהדיירים'), findsOneWidget);
    expect(find.byKey(const Key('inquiries-unread')), findsOneWidget);

    await tester.tap(find.byKey(const Key('committee-inquiries')));
    await tester.pumpAndSettle();
    expect(find.text('דנה לוי · דירה 2'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('inquiry-$id')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('inquiry-reply')),
      'נדבר איתם השבוע',
    );
    await tester.tap(find.byKey(const Key('inquiry-reply-send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inquiry-handled')));
    await tester.pumpAndSettle();
    expect(find.text('פתיחה מחדש'), findsOneWidget);
    expect((await c.inquiries.list('b')).inbox.single.handled, isTrue);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('טופלו'), findsOneWidget);
  });

  test('inquiry times read naturally', () {
    final now = DateTime(2026, 11, 24, 20);
    expect(
      inquiryTime(DateTime(2026, 11, 24, 9, 5), now: now),
      contains('09:05'),
    );
    expect(
      inquiryTime(DateTime(2026, 11, 24, 9, 5), now: now),
      startsWith('היום'),
    );
    expect(
      inquiryTime(DateTime(2026, 11, 23, 9), now: now),
      startsWith('אתמול'),
    );
    expect(inquiryTime(DateTime(2026, 11, 2, 9), now: now), contains('2.11'));
  });
}
