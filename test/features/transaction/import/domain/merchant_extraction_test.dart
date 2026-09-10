import 'package:budget_view/features/transaction/import/domain/merchant_extraction.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every string here is a real purpose text from an ING Girokonto statement —
/// PayPal's from January 2026, the card acquirers' from September 2026 — including
/// the mid-word line breaks the statement's column wrap produces. No document
/// enters the repo; these lines do.
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

  group('a card acquirer names the shop in the leading segment', () {
    test('the segment before the first slash is the merchant', () {
      expect(
        extractMerchant(
          'Salon Pia Bruchmann/An der Hardt 1b /Knigswinter/DE '
          '2026-08-26T17:53:18 Folgenr.000 Verfalld.2029-12',
          counterparty: 'Adyen N.V.',
        ),
        'Salon Pia Bruchmann',
      );
    });

    test('a swallowed space stays in the key', () {
      expect(
        extractMerchant(
          'BootshausRadolfzell/Schlossstrae 12 /Gaienhofen/DE '
          '2026-08-30T12:13:27 Folgenr.000 Verfalld.2029-12',
          counterparty: 'Adyen N.V.',
        ),
        'BootshausRadolfzell',
      );
    });

    test('a Lastschrift prefix is stripped off the merchant', () {
      expect(
        extractMerchant(
          'LS Akropolis Grill Loh/Hauptstrae 8 9/Lohmar/DE '
          '2026-07-31T13:32:47 Fol genr.001 Verfalld.2029-12',
          counterparty: 'Adyen N.V.',
        ),
        'Akropolis Grill Loh',
      );
    });

    test('Nexi loses its booking reference', () {
      expect(
        extractMerchant(
          'BAECKEREI SCHMIDT E K INHA 301 Refr GIR 79998979//BERGISCH '
          'GLADBAC/DE 2026-08-12T09:37:33 Folgenr.001 Ver falld.2029-12',
          counterparty: 'Nexi Germany GmbH',
        ),
        'BAECKEREI SCHMIDT E K INHA 301',
      );
    });

    test('casing and spacing variants of the payer name still hit', () {
      expect(
        extractMerchant(
          'Salon Pia Bruchmann/An der Hardt 1b /Knigswinter/DE',
          counterparty: '  adyen   n.v.  ',
        ),
        'Salon Pia Bruchmann',
      );
    });

    test('an ordinary card payment keeps its single rule', () {
      // Same shape, but KAUFLAND already is the shop. A merchant here would split
      // one rule into one per branch — which is why the list keys on the name.
      expect(
        extractMerchant(
          'Kaufland Bergisch Gladbach//Bergisc h Gladbach/DE '
          '2025-12-30T17:34:09 F olgenr.000 Verfalld.2029-12',
          counterparty: 'KAUFLAND',
        ),
        isNull,
      );
    });

    test('a listed payer whose segment is empty falls back to null', () {
      expect(
        extractMerchant(
          '/An der Hardt 1b /Knigswinter/DE 2026-08-26T17:53:18',
          counterparty: 'Adyen N.V.',
        ),
        isNull,
      );
    });

    test('without a counterparty only the PayPal path runs', () {
      expect(
        extractMerchant(
          'Salon Pia Bruchmann/An der Hardt 1b /Knigswinter/DE',
        ),
        isNull,
      );
    });
  });
}
