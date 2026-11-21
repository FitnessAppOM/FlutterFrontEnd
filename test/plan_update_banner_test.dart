import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/core/account_storage.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/widgets/training/plan_update_banner.dart';

void main() {
  late Map<String, dynamic> job;

  setUp(() {
    SharedPreferences.setMockInitialValues({'user_id': 42});
    FlutterSecureStorage.setMockInitialValues({});
    job = {'job_id': 145, 'attempt': 1, 'status': 'failed', 'retryable': false};
  });

  Future<void> withServer(Future<void> Function() body) => http.runWithClient(
    body,
    () => MockClient((request) async {
      expectSync(request.method, 'GET');
      expectSync(request.url.path, contains('/training/generation/status/'));
      return http.Response(jsonEncode({'generation': job}), 200);
    }),
  );

  Future<void> pumpBanner(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [AppLocalizationsDelegate()],
        home: Scaffold(body: PlanUpdateBanner()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> refresh(WidgetTester tester) async {
    AccountStorage.notifyTrainingChanged();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> dismiss(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  }

  for (final status in ['failed', 'superseded']) {
    testWidgets('$status dismissal survives refresh and reopening', (
      tester,
    ) async {
      job['status'] = status;
      await withServer(() async {
        await pumpBanner(tester);
        expect(
          find.text(
            'This update couldn’t finish because your plan changed or the request is outdated. Check with your coach. Tap × to dismiss.',
          ),
          findsOneWidget,
        );
        await dismiss(tester);
        await refresh(tester);
        expect(find.byType(Card), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await pumpBanner(tester);
        expect(find.byType(Card), findsNothing);
      });
    });
  }

  testWidgets('a different update shows its own warning', (tester) async {
    await withServer(() async {
      await pumpBanner(tester);
      await dismiss(tester);
      job['job_id'] = 146;
      await refresh(tester);
      expect(find.byTooltip('Close'), findsOneWidget);
    });
  });

  testWidgets('retrying a dismissed job shows pending and a new failure', (
    tester,
  ) async {
    job['retryable'] = true;
    await withServer(() async {
      await pumpBanner(tester);
      expect(find.text('Try again'), findsOneWidget);
      await dismiss(tester);
      job['attempt'] = 2;
      for (final status in ['queued', 'running']) {
        job['status'] = status;
        await refresh(tester);
        expect(find.text('Check update'), findsOneWidget);
        expect(find.byTooltip('Close'), findsNothing);
      }
      job['status'] = 'failed';
      await refresh(tester);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('dismissal belongs to the account that acknowledged it', (
    tester,
  ) async {
    await withServer(() async {
      await pumpBanner(tester);
      await dismiss(tester);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt('user_id', 99);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpBanner(tester);
      expect(find.byTooltip('Close'), findsOneWidget);

      await preferences.setInt('user_id', 42);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpBanner(tester);
      expect(find.byType(Card), findsNothing);
    });
  });
}
