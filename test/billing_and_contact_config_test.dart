import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/pages/billing_screen.dart').readAsStringSync();

  test('the three enterprise plans have an actionable Stripe link', () {
    const links = <String>[
      'https://buy.stripe.com/6oU00j72W5u3gMR8QFc3m02',
      'https://buy.stripe.com/9B614nevo09J68d1odc3m01',
      'https://buy.stripe.com/cNi8wP0Eyg8HeEJ4Apc3m00',
    ];

    for (final link in links) {
      expect(source, contains(link));
    }
    expect(source, contains('onPressed: isOpening ? null : onPurchase'));
    expect(source, contains('launchUrl(uri'));
  });

  test('the contact form opens a real email composer', () {
    expect(source, contains("scheme: 'mailto'"));
    expect(source, contains("path: 'contact@digitalsolutionsai.com'"));
    expect(source, contains("'subject': subject"));
    expect(source, contains("'body': body"));
  });
}
