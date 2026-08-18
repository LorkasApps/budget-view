import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      final changes = StreamGroup.merge([
        isar.transactions.watchLazy(),
        isar.lineItems.watchLazy(),
        isar.categorys.watchLazy(),
        isar.accounts.watchLazy(),
      ]);
      await for (final _ in changes) {
        yield await compute();
      }
    });
