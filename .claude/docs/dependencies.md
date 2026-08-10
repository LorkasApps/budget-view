# Domain Dependencies

```
Infra              (base: Flutter, Isar, Supabase-stub)
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
- Drilldown line-items override parent Transaction category (fractal rule).
- Tagging learns from user-assigned Transaction↔Category pairs.
- Analytics reads across Transaction + Drilldown for reports.
