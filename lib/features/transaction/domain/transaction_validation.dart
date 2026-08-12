import '../../../core/money/money.dart';

/// Pure form validators for the transaction form.
class TransactionValidation {
  const TransactionValidation._();

  static String? description(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Beschreibung erforderlich';
    }
    return null;
  }

  /// Validates the magnitude field (sign comes from the expense/income toggle).
  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Betrag erforderlich';
    }
    final cents = parseEurosToCents(value);
    if (cents == null) {
      return 'Ungültiger Betrag';
    }
    if (cents == 0) {
      return 'Betrag darf nicht 0 sein';
    }
    if (cents < 0) {
      return 'Betrag ohne Vorzeichen eingeben';
    }
    return null;
  }

  static String? bookingDate(DateTime? value, {DateTime? now}) {
    if (value == null) {
      return 'Datum erforderlich';
    }
    if (value.isAfter(now ?? DateTime.now())) {
      return 'Datum darf nicht in der Zukunft liegen';
    }
    return null;
  }

  /// Manual entry requires a category. PDF import deliberately does not call
  /// this — imported rows may stay uncategorized.
  static String? category(String? categoryUuid) {
    if (categoryUuid == null || categoryUuid.isEmpty) {
      return 'Kategorie erforderlich';
    }
    return null;
  }

  static String? account(String? accountUuid) {
    if (accountUuid == null || accountUuid.isEmpty) {
      return 'Konto erforderlich';
    }
    return null;
  }
}
