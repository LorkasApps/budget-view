# Domain Dependencies

```
Infra              (base: Flutter, Isar, Supabase-stub)
Import             → Infra, Transaction (dedupe queries)
Account            → Infra, Transaction (balance needs transaction sums)
Transaction        → Account, Category
Category           → Infra
Drilldown          → Transaction
Tagging            → Transaction, Category
Analytics          → Transaction, Category, Drilldown
```

Note the Account↔Transaction cycle is intentional and narrow: `LocalBalanceService`
(account/data) injects `TransactionRepository` for `sumForAccount`, while
transactions reference accounts by `accountUuid`. No other account code depends
on the transaction feature.

## Notes
- Category assignment is on Transaction (1 category per entry, tree-aware).
- Account's dependency on Category is navigation only: `AccountListScreen`'s app bar opens `CategoryTreeScreen`. No account data or logic touches the category feature.
- `Import` holds what every import path shares: `ImportedSource`, the document hash and `DuplicateChecker`. Format-specific code stays in its own feature — the ING parser and PDF flow remain under `Transaction`. `Transaction → Import` for the dedupe checks and the import flow; `Drilldown → Import` once photo scanning lands. Never the reverse.
- Category → Transaction is a second intentional narrow cycle (alongside Account ↔ Transaction): `CategoryRepository` injects `TransactionRepository` solely for `countByCategory`, so `delete` can refuse to archive a category still in use. Nothing else in the category feature touches transactions.
- Drilldown line-items override parent Transaction category (fractal rule).
- Tagging learns from user-assigned Transaction↔Category pairs.
- Analytics reads across Transaction + Drilldown for reports.
