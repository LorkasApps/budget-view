import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../../core/persistence/isar_provider.dart';
// The collection getters below are extensions from these entity libraries.
import '../../account/data/account.dart';
import '../../account/domain/account_providers.dart';
import '../../category/data/category.dart';
import '../../category/domain/category_providers.dart';
import '../../drilldown/data/line_item.dart';
import '../../drilldown/domain/line_item_providers.dart';
import '../../transaction/data/transaction.dart';
import '../../transaction/domain/transaction_providers.dart';
import 'forecast.dart';
import 'forecast_service.dart';
import 'item_price_trend.dart';
import 'item_price_trend_service.dart';
import 'monthly_category_report.dart';
import 'monthly_category_report_service.dart';

final monthlyCategoryReportServiceProvider =
    Provider<MonthlyCategoryReportService>(
      (ref) => MonthlyCategoryReportService(
        ref.watch(transactionRepositoryProvider),
        ref.watch(lineItemRepositoryProvider),
        ref.watch(categoryRepositoryProvider),
        ref.watch(accountRepositoryProvider),
      ),
    );

/// Recomputes on any write to the four collections a report reads. Mirrors
/// `LocalBalanceService`: initial snapshot first, then one merged change signal.
final monthlyCategoryReportProvider =
    StreamProvider.family<MonthlyCategoryReport, MonthlyReportFilter>((
      ref,
      filter,
    ) async* {
      final isar = ref.watch(isarProvider);
      final service = ref.watch(monthlyCategoryReportServiceProvider);

      Future<MonthlyCategoryReport> compute() => service.compute(
        year: filter.year,
        month: filter.month,
        accountUuid: filter.accountUuid,
        direction: filter.direction,
      );

      yield await compute();
      await for (final _ in _dataChanges(isar)) {
        yield await compute();
      }
    });

final forecastServiceProvider = Provider<ForecastService>(
  (ref) => ForecastService(ref.watch(monthlyCategoryReportServiceProvider)),
);

final forecastProvider =
    StreamProvider.family<ForecastResult, ForecastFilter>((ref, filter) async* {
      final isar = ref.watch(isarProvider);
      final service = ref.watch(forecastServiceProvider);

      Future<ForecastResult> compute() => service.compute(
        categoryUuid: filter.categoryUuid,
        anchorMonth: filter.anchor,
        windowMonths: filter.windowMonths,
        horizonMonths: filter.horizonMonths,
        accountUuid: filter.accountUuid,
        direction: filter.direction,
      );

      yield await compute();
      await for (final _ in _dataChanges(isar)) {
        yield await compute();
      }
    });

final itemPriceTrendServiceProvider = Provider<ItemPriceTrendService>(
  (ref) => ItemPriceTrendService(
    ref.watch(transactionRepositoryProvider),
    ref.watch(lineItemRepositoryProvider),
    ref.watch(accountRepositoryProvider),
  ),
);

/// Both item providers are `autoDispose`, unlike the report ones: their family
/// key is a search string resp. an item description, so the number of keys
/// grows with typing instead of being bounded by a filter's fields.
final itemGroupSearchProvider = StreamProvider.autoDispose
    .family<List<ItemGroup>, String>((ref, query) async* {
      final isar = ref.watch(isarProvider);
      final service = ref.watch(itemPriceTrendServiceProvider);

      yield await service.searchGroups(query);
      await for (final _ in _dataChanges(isar)) {
        yield await service.searchGroups(query);
      }
    });

final itemPriceSeriesProvider = StreamProvider.autoDispose
    .family<ItemPriceSeries, String>((ref, normalizedKey) async* {
      final isar = ref.watch(isarProvider);
      final service = ref.watch(itemPriceTrendServiceProvider);

      yield await service.series(normalizedKey);
      await for (final _ in _dataChanges(isar)) {
        yield await service.series(normalizedKey);
      }
    });

/// One signal for any write that can move a report or a forecast.
Stream<void> _dataChanges(Isar isar) => StreamGroup.merge([
  isar.transactions.watchLazy(),
  isar.lineItems.watchLazy(),
  isar.categorys.watchLazy(),
  isar.accounts.watchLazy(),
]);
