import 'package:budget_view/features/transaction/import/domain/merchant_extraction.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every string here is a real purpose text from an ING Girokonto statement of
/// January 2026, including the mid-word line breaks the statement's column wrap
/// produces. No document enters the repo; these lines do.
void main() {
  test('takes the unbroken of the two spellings', () {
    expect(
      extractMerchant(
        '1047390819119/PP.4163.PP/. Picnic G mbH, Ihr Einkauf bei Picnic GmbH',
      ),
      'Picnic GmbH',
    );
    expect(
      extractMerchant(
        '1047426328482/PP.4163.PP/. HomeVisi on, Ihr Einkauf bei HomeVision',
      ),
      'HomeVision',
    );
    expect(
      extractMerchant(
        '1047437247968/PP.4163.PP/. Takeaway .com Payments B.V., Ihr Einkauf '
        'bei Takeaway.com Payments B.V.',
      ),
      'Takeaway.com Payments B.V.',
    );
  });

  test('a refund names its merchant too, without a reference block', () {
    expect(
      extractMerchant(
        '. HomeVision, Ihr Einkauf bei HomeV ision/ABBUCHUNG VOM PAYPAL-KONTO',
      ),
      'HomeVision',
    );
    expect(
      extractMerchant(
        '. Picnic GmbH, Ihr Einkauf bei Picn ic GmbH/ABBUCHUNG VOM '
        'PAYPAL-KONTO',
      ),
      'Picnic GmbH',
    );
  });

  test('a row that names no merchant yields null', () {
    // Real line, 5,00 €: the merchant is missing and the keyword itself is broken.
    expect(
      extractMerchant('1047426748046/PP.4163.PP/. , Ihr Ei nkauf bei'),
      isNull,
    );
  });

  test('an ordinary direct debit is left alone', () {
    expect(
      extractMerchant(
        '0000113025335 0020701296237 Rechnungsnr: 121948928274 KdNr. '
        '113025335 Vodafone sagt Danke',
      ),
      isNull,
    );
    expect(
      extractMerchant('257.234.594-2 Abschlag Jan Bernard-Eyberg-Str. 80 a'),
      isNull,
    );
  });
}
