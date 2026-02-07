import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/diet/diet_service.dart';
import '../theme/app_theme.dart';

class DietFavoritesSheet extends StatefulWidget {
  const DietFavoritesSheet({
    super.key,
    required this.rootContext,
    required this.userId,
    required this.mealId,
    required this.mealTitle,
    this.trainingDayId,
    required this.onLogged,
  });

  /// Use a stable parent context (Scaffold) for SnackBars.
  final BuildContext rootContext;
  final int userId;
  final int mealId;
  final String mealTitle;
  final int? trainingDayId;
  final Future<void> Function(Map<String, dynamic>? daySummary) onLogged;

  @override
  State<DietFavoritesSheet> createState() => _DietFavoritesSheetState();
}

class _DietFavoritesSheetState extends State<DietFavoritesSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await DietService.fetchFavoriteMeals(widget.userId);
      if (!mounted) return;
      setState(() {
        _favorites = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _logFavorite(int favoriteId) async {
    final t = AppLocalizations.of(context);
    try {
      final response = await DietService.logFavoriteMeal(
        userId: widget.userId,
        favoriteMealId: favoriteId,
        mealId: widget.mealId,
        trainingDayId: widget.trainingDayId,
      );
      final daySummary = response["day_summary"] is Map
          ? (response["day_summary"] as Map).cast<String, dynamic>()
          : null;
      if (!mounted) return;
      if (widget.rootContext.mounted) {
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          SnackBar(content: Text(t.translate("diet_favorites_log_success"))),
        );
      }
      final onLogged = widget.onLogged;
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onLogged(daySummary);
      });
    } catch (e) {
      if (!mounted) return;
      if (widget.rootContext.mounted) {
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          SnackBar(
            content: Text("${t.translate("diet_favorites_log_failed")}: $e"),
          ),
        );
      }
    }
  }

  Future<void> _showFavoriteDetail(Map<String, dynamic> fav) async {
    final t = AppLocalizations.of(context);
    final favId = int.tryParse(fav['id']?.toString() ?? '');
    if (favId == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          title: Text(fav['meal_name']?.toString() ?? ''),
          content: FutureBuilder<Map<String, dynamic>>(
            future: DietService.fetchFavoriteMealDetail(
              userId: widget.userId,
              favoriteMealId: favId,
            ),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  "${t.translate("diet_favorites_load_failed")}: ${snapshot.error}",
                  style: const TextStyle(color: AppColors.errorRed),
                );
              }
              final data = snapshot.data ?? {};
              final items = data['items'];
              final list = items is List
                  ? items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
                  : <Map<String, dynamic>>[];
              if (list.isEmpty) {
                return Text(t.translate("diet_no_results"));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((data['notes'] ?? '').toString().trim().isNotEmpty) ...[
                    Text(
                      data['notes'].toString(),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ...list.map((item) {
                    final name = (item['item_name'] ?? '').toString();
                    final kcal = item['calories'] ?? 0;
                    final p = item['protein_g'] ?? 0;
                    final c = item['carbs_g'] ?? 0;
                    final f = item['fat_g'] ?? 0;
                    final grams = item['grams'];
                    final ingredients = item['ingredients'];
                    final ingList = ingredients is List
                        ? ingredients.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
                        : <Map<String, dynamic>>[];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            "${t.translate("diet_kcal_label")} $kcal • "
                            "${t.translate("diet_p_short")} $p • "
                            "${t.translate("diet_c_short")} $c • "
                            "${t.translate("diet_f_short")} $f"
                            "${grams != null ? " • ${grams}g" : ""}",
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          if (ingList.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              ingList
                                  .map((ing) {
                                    final n = (ing['ingredient_name'] ?? '').toString();
                                    final amt = ing['amount'];
                                    final unit = (ing['unit'] ?? '').toString();
                                    final amountLabel = amt != null ? " ${amt.toString()}" : "";
                                    final unitLabel = unit.isNotEmpty ? " $unit" : "";
                                    return "$n$amountLabel$unitLabel";
                                  })
                                  .where((e) => e.trim().isNotEmpty)
                                  .join(" • "),
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t.translate("common_cancel")),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _logFavorite(favId);
              },
              child: Text(t.translate("diet_favorites_log")),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  height: 5,
                  width: 44,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.translate("diet_favorites_title"),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loading ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.mealTitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: AppColors.errorRed),
                              ),
                            )
                          : _favorites.isEmpty
                              ? Center(
                                  child: Text(
                                    t.translate("diet_favorites_empty"),
                                    style: const TextStyle(color: Colors.white60),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _favorites.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(color: AppColors.dividerDark, height: 1),
                                  itemBuilder: (ctx, i) {
                                    final fav = _favorites[i];
                                    final title = fav['meal_name']?.toString() ?? '';
                                    final notes = fav['notes']?.toString() ?? '';
                                    final dynamicCount = fav['item_count'] ?? (fav['items'] is List ? (fav['items'] as List).length : null);
                                    final count = (dynamicCount ?? 0).toString();
                                    return ListTile(
                                      title: Text(title, style: const TextStyle(color: Colors.white)),
                                      subtitle: Text(
                                        notes.isNotEmpty
                                            ? "$notes • $count ${t.translate("diet_items_plural")}"
                                            : "$count ${t.translate("diet_items_plural")}",
                                        style: const TextStyle(color: Colors.white60),
                                      ),
                                      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                                      onTap: () => _showFavoriteDetail(fav),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
