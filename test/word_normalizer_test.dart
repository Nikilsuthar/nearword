import 'package:flutter_test/flutter_test.dart';
import 'package:nearword/core/utils/word_normalizer.dart';

void main() {
  group('WordNormalizer.normalize', () {
    test('trims and lowercases', () {
      expect(WordNormalizer.normalize('  DoG '), 'dog');
    });
    test('removes accents', () {
      expect(WordNormalizer.clean('Café'), 'cafe');
      expect(WordNormalizer.clean('jalapeño'), 'jalapeno');
    });
    test('singularizes simple plurals', () {
      expect(WordNormalizer.normalize('dogs'), 'dog');
      expect(WordNormalizer.normalize('berries'), 'berry');
      expect(WordNormalizer.normalize('boxes'), 'box');
      expect(WordNormalizer.normalize('glasses'), 'glass');
    });
    test('leaves non-plurals alone', () {
      expect(WordNormalizer.normalize('bus'), 'bus');
      expect(WordNormalizer.normalize('glass'), 'glass');
      expect(WordNormalizer.normalize('analysis'), 'analysis');
    });
    test('candidates tries exact form before singular', () {
      expect(WordNormalizer.candidates('Cats'), ['cats', 'cat']);
      expect(WordNormalizer.candidates('dog'), ['dog']);
    });
    test('isValid accepts only letters', () {
      expect(WordNormalizer.isValid('dog'), isTrue);
      expect(WordNormalizer.isValid('d0g'), isFalse);
      expect(WordNormalizer.isValid(''), isFalse);
    });
  });
}
