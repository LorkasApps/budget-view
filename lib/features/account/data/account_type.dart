/// Bank account kind. `other` is the catch-all (Depot, Kredit, Bargeld, ...).
enum AccountType { giro, tagesgeld, sparkonto, other }

extension AccountTypeLabel on AccountType {
  String get label => switch (this) {
        AccountType.giro => 'Giro',
        AccountType.tagesgeld => 'Tagesgeld',
        AccountType.sparkonto => 'Sparkonto',
        AccountType.other => 'Sonstiges',
      };
}
