import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../domain/analytics_providers.dart';
import '../domain/item_price_trend.dart';
import 'item_price_chart_screen.dart';

/// Search over every item ever booked as a position, by description.
///
/// A search instead of a full list: the catalogue grows with every receipt, and
/// the question this screen answers is always about one item the user has in
/// mind.
class ItemPriceTrendScreen extends ConsumerStatefulWidget {
  const ItemPriceTrendScreen({super.key});

  @override
  ConsumerState<ItemPriceTrendScreen> createState() =>
      _ItemPriceTrendScreenState();
}

class _ItemPriceTrendScreenState extends ConsumerState<ItemPriceTrendScreen> {
  static const _debounceDelay = Duration(milliseconds: 300);

  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Every keystroke would otherwise re-scan all positions of all bookings.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _open(ItemGroup group) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ItemPriceChartScreen(
        normalizedKey: group.normalizedKey,
        title: group.label,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Preistrends')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Artikel suchen',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _Results(query: _query, onTap: _open)),
      ],
    ),
  );
}

class _Results extends ConsumerWidget {
  const _Results({required this.query, required this.onTap});

  final String query;
  final ValueChanged<ItemGroup> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().isEmpty) {
      return const _Hint('Artikel suchen, um seinen Preisverlauf zu sehen');
    }

    return ref.watch(itemGroupSearchProvider(query)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Hint('Artikel nicht ladbar: $error'),
      data: (groups) {
        if (groups.isEmpty) return const _Hint('Keine Artikel gefunden');

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return ListTile(
              title: Text(group.label),
              subtitle: Text(_purchaseLabel(group.purchaseCount)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatCentsEur(group.latestUnitPriceCents)),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => onTap(group),
            );
          },
        );
      },
    );
  }
}

String _purchaseLabel(int count) => count == 1 ? '1 Kauf' : '$count Käufe';

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(child: Text(text, textAlign: TextAlign.center)),
  );
}
