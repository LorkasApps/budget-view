import '../../../core/money/money.dart';

/// Pure field checks for the line-item edit sheet. The repository re-checks the
/// hard rules; [amountMismatch] is UI-only on purpose — see the ticket.
class LineItemValidation {
  const LineItemValidation._();

  static const maxDescriptionLength = 120;

  static String? description(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Beschreibung erforderlich';
    if (trimmed.length > maxDescriptionLength) {
      return 'Beschreibung zu lang (max. $maxDescriptionLength Zeichen)';
    }
    return null;
  }

  /// Unsigned magnitude — the sign comes from the parent transaction.
  static String? amount(int? cents) {
    if (cents == null) return 'Betrag erforderlich';
    if (cents == 0) return 'Betrag darf nicht 0 sein';
    if (cents < 0) return 'Betrag ohne Vorzeichen eingeben';
    return null;
  }

  static String? quantity(double? value) {
    if (value == null) return null;
    if (value <= 0) return 'Menge muss größer als 0 sein';
    return null;
  }

  static String? unitPrice(int? cents) {
    if (cents == null) return null;
    if (cents <= 0) return 'Preis muss größer als 0 sein';
    return null;
  }

  /// Warning text when `quantity × unitPrice` misses [amountCents] by more than
  /// a cent, else null. Never a rejection: discount rows break the product on
  /// purpose.
  static String? amountMismatch({
    double? quantity,
    int? unitPriceCents,
    required int amountCents,
  }) {
    if (quantity == null || unitPriceCents == null) return null;
    final expected = (quantity * unitPriceCents).round();
    if ((expected - amountCents.abs()).abs() <= 1) return null;
    return '${formatCentsEur(expected)} erwartet '
        '(${quantityLabel(quantity)} × ${formatCentsEur(unitPriceCents)})';
  }

  /// Trailing `.0` dropped, decimal comma — for both the warning text and the
  /// edit sheet's prefilled field.
  static String quantityLabel(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toStringAsFixed(0);
    }
    return quantity.toString().replaceAll('.', ',');
  }
}
