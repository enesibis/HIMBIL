import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/net/deep_link_service.dart';

void main() {
  group('DeepLinkService.roomCodeFrom', () {
    test('extracts and uppercases the code from a valid invite link', () {
      expect(DeepLinkService.roomCodeFrom(Uri.parse('himbil://join/fp52em')), 'FP52EM');
    });

    test('returns null for a different scheme', () {
      expect(DeepLinkService.roomCodeFrom(Uri.parse('https://join/FP52EM')), isNull);
    });

    test('returns null for a different host', () {
      expect(DeepLinkService.roomCodeFrom(Uri.parse('himbil://spectate/FP52EM')), isNull);
    });

    test('returns null when no code segment is present', () {
      expect(DeepLinkService.roomCodeFrom(Uri.parse('himbil://join/')), isNull);
      expect(DeepLinkService.roomCodeFrom(Uri.parse('himbil://join')), isNull);
    });
  });
}
