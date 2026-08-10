# Domain Dependencies

```
Infra              (base: Flutter, Isar, Supabase-stub)
Account            → Infra
Transaction        → Account, Category
Category           → Infra
Drilldown          → Transaction
Tagging            → Transaction, Category
Analytics          → Transaction, Category, Drilldown
```

## Notes
- Category assignment is on Transaction (1 category per entry, tree-aware).
- Drilldown line-items override parent Transaction category (fractal rule).
- Tagging learns from user-assigned Transaction↔Category pairs.
- Analytics reads across Transaction + Drilldown for reports.
