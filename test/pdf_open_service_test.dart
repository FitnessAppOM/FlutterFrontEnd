import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/core/pdf_document_validation.dart';
import 'package:taqaproject/services/core/pdf_open_service.dart';

void main() {
  group('PdfOpenService', () {
    test('distinguishes PDF links from web articles', () {
      expect(
        PdfOpenService.isPdfUrl(
          'https://storage.example.com/news/guide.pdf?signature=abc',
        ),
        isTrue,
      );
      expect(
        PdfOpenService.isPdfUrl(
          'https://taqafitness.com/articles/training-with-intent-rir',
        ),
        isFalse,
      );
    });

    test('recognizes a PDF header and rejects HTML', () {
      expect(hasPdfSignature('%PDF-1.7\n'.codeUnits), isTrue);
      expect(
        hasPdfSignature('<!doctype html><html></html>'.codeUnits),
        isFalse,
      );
    });
  });
}
