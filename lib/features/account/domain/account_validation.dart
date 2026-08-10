import '../../../core/money/money.dart';

/// Pure form validators for the account form. Return an error string or `null`.
class AccountValidation {
  const AccountValidation._();

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name erforderlich';
    }
    return null;
  }

  static String? openingBalance(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Betrag erforderlich';
    }
    if (parseEurosToCents(value) == null) {
      return 'Ungültiger Betrag';
    }
    return null;
  }

  static String? openingDate(DateTime? value, {DateTime? now}) {
    if (value == null) {
      return 'Datum erforderlich';
    }
    final reference = now ?? DateTime.now();
    if (value.isAfter(reference)) {
      return 'Datum darf nicht in der Zukunft liegen';
    }
    return null;
  }
}
