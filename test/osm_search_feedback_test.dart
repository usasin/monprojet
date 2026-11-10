import 'package:ai_prospect_gps/widgets/osm_search_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an error remains discoverable and its retry action works',
      (tester) async {
    var retries = 0;
    const message =
        'Location unavailable. Check your connection and try again.';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OSMSearchFeedback(
          message: message,
          isError: true,
          onRetry: () => retries += 1,
        ),
      ),
    ));

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Search needs retry'), findsOneWidget);
    expect(find.text(message), findsNothing); // details are disclosed on tap
    await tester.tap(find.text('Search needs retry'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty-result chip reveals guidance without showing retry',
      (tester) async {
    const message = 'No prospects found. Change the category or search area.';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: OSMSearchFeedback(message: message)),
    ));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('No results'), findsOneWidget);
    expect(find.text(message), findsNothing);
    await tester.tap(find.text('No results'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long feedback and retry fit a narrow screen with enlarged text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const message =
        'The service is busy. Your previous selection is still available. '
        'Please wait a moment before trying another search.';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: OSMSearchFeedback(
            message: message,
            isError: true,
            onRetry: () {},
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Search needs retry'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
