import '../data/transaction.dart';
import 'pdf/parse_result.dart';

/// Maps a parsed candidate onto an unsaved [Transaction]. `uuid`, `createdAt`
/// and `updatedAt` stay unset — `TransactionRepository.save` fills them.
///
/// [ParsedTransactionCandidate.valueDate] is dropped: the entity has no
/// Wertstellung field yet.
Transaction candidateToTransaction(
  ParsedTransactionCandidate candidate, {
  required String accountUuid,
}) {
  return Transaction()
    ..accountUuid = accountUuid
    ..amountCents = candidate.amountCents
    ..bookingDate = candidate.bookingDate
    ..description = candidate.description
    ..counterparty = candidate.counterparty ?? '';
}
