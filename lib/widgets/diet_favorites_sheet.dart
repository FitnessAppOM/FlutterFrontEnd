import 'package:flutter/material.dart';
import '../core/user_friendly_error.dart';
import '../localization/app_localizations.dart';
import '../services/diet/diet_service.dart';
import '../theme/app_theme.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';

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
        _error = userFriendlyErrorMessage(e);
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
        AppToast.show(
          widget.rootContext,
          t.translate("diet_favorites_log_success"),
          type: AppToastType.success,
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
        AppToast.show(
          widget.rootContext,
          "${t.translate("diet_favorites_log_failed")}: $e",
          type: AppToastType.error,
        );
      }
    }
  }

  Future<void> _showFavoriteDetail(Map<String, dynamic> fav) async {
    final favId = int.tryParse(fav['id']?.toString() ?? '');
    if (favId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TaqaUiScale.r(15)),
        ),
      ),
      builder: (ctx) => _FavoriteDetailSheet(
        title: fav['meal_name']?.toString() ?? '',
        userId: widget.userId,
        favoriteMealId: favId,
        onLog: () {
          Navigator.of(ctx).pop();
          _logFavorite(favId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Padding(
            padding: TaqaUiScale.insetsLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(
                  height: 5,
                  width: 44,
                  margin: EdgeInsets.only(bottom: TaqaUiScale.h(16)),
                  decoration: BoxDecoration(
                    color: TaqaUiColors.unnamedColor1c1d17.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      t.translate("diet_favorites_title"),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(15),
                        fontWeight: FontWeight.w700,
                        height: 25 / 15,
                        letterSpacing: 0,
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: TaqaUiColors.unnamedColor1c1d17,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: TaqaUiScale.h(12)),
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
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              color: TaqaUiColors.unnamedColor1c1d17.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _favorites.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: TaqaUiScale.h(12)),
                          itemBuilder: (ctx, i) {
                            final fav = _favorites[i];
                            final title = fav['meal_name']?.toString() ?? '';
                            final notes = fav['notes']?.toString() ?? '';
                            final dynamicCount =
                                fav['item_count'] ??
                                (fav['items'] is List
                                    ? (fav['items'] as List).length
                                    : null);
                            final count = (dynamicCount ?? 0).toString();
                            final subtitle = notes.isNotEmpty
                                ? "$notes • $count ${t.translate("diet_items_plural")}"
                                : "$count ${t.translate("diet_items_plural")}";
                            return InkWell(
                              borderRadius: TaqaUiScale.radius(15),
                              onTap: () => _showFavoriteDetail(fav),
                              child: Container(
                                padding: TaqaUiScale.insetsLTRB(14, 10, 14, 15),
                                decoration: BoxDecoration(
                                  color: TaqaUiColors.white,
                                  borderRadius: TaqaUiScale.radius(15),
                                  border: Border.all(
                                    color: TaqaUiColors.unnamedColor1c1d17
                                        .withValues(alpha: 0.10),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily:
                                                  TaqaUiFontFamilies.interTight,
                                              fontSize: TaqaUiScale.sp(15),
                                              fontWeight: FontWeight.w700,
                                              height: 21 / 15,
                                              letterSpacing: 0,
                                              color: TaqaUiColors
                                                  .unnamedColor1c1d17,
                                            ),
                                          ),
                                          SizedBox(height: TaqaUiScale.h(2)),
                                          Text(
                                            subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily:
                                                  TaqaUiFontFamilies.interTight,
                                              fontSize: TaqaUiScale.sp(13),
                                              fontWeight: FontWeight.w400,
                                              height: 18 / 13,
                                              letterSpacing: 0,
                                              color: TaqaUiColors
                                                  .unnamedColor1c1d17
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: TaqaUiScale.w(8)),
                                    Icon(
                                      Icons.chevron_right,
                                      color: TaqaUiColors.unnamedColor1c1d17
                                          .withValues(alpha: 0.4),
                                    ),
                                  ],
                                ),
                              ),
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

class _FavoriteDetailSheet extends StatelessWidget {
  const _FavoriteDetailSheet({
    required this.title,
    required this.userId,
    required this.favoriteMealId,
    required this.onLog,
  });

  final String title;
  final int userId;
  final int favoriteMealId;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding: TaqaUiScale.insetsLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Container(
                height: 5,
                width: 44,
                margin: EdgeInsets.only(bottom: TaqaUiScale.h(16)),
                decoration: BoxDecoration(
                  color: TaqaUiColors.unnamedColor1c1d17.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w700,
                      height: 25 / 15,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: TaqaUiScale.h(12)),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: DietService.fetchFavoriteMealDetail(
                    userId: userId,
                    favoriteMealId: favoriteMealId,
                  ),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "${t.translate("diet_favorites_load_failed")}: ${snapshot.error}",
                          style: const TextStyle(color: AppColors.errorRed),
                        ),
                      );
                    }
                    final data = snapshot.data ?? {};
                    final items = data['items'];
                    final list = items is List
                        ? items
                              .whereType<Map>()
                              .map((e) => e.cast<String, dynamic>())
                              .toList()
                        : <Map<String, dynamic>>[];
                    final notes = (data['notes'] ?? '').toString().trim();
                    if (list.isEmpty) {
                      return Center(
                        child: Text(
                          t.translate("diet_no_results"),
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            color: TaqaUiColors.unnamedColor1c1d17,
                          ),
                        ),
                      );
                    }
                    return ListView(
                      children: [
                        if (notes.isNotEmpty) ...[
                          Text(
                            notes,
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(13),
                              color: TaqaUiColors.unnamedColor1c1d17.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          SizedBox(height: TaqaUiScale.h(12)),
                        ],
                        ...list.map(
                          (item) => Padding(
                            padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
                            child: _buildFavoriteItem(t, item),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: TaqaUiScale.h(12)),
              Material(
                color: TaqaUiColors.unnamedColorE4e93b,
                borderRadius: TaqaUiScale.radius(5),
                child: InkWell(
                  borderRadius: TaqaUiScale.radius(5),
                  onTap: onLog,
                  child: SizedBox(
                    width: double.infinity,
                    height: TaqaUiScale.h(45),
                    child: Center(
                      child: Text(
                        t.translate("diet_favorites_log").toUpperCase(),
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(10),
                          fontWeight: FontWeight.w600,
                          height: 12 / 10,
                          letterSpacing: 0,
                          color: TaqaUiColors.unnamedColor1c1d17,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteItem(AppLocalizations t, Map<String, dynamic> item) {
    final name = (item['item_name'] ?? '').toString();
    final kcal = item['calories'] ?? 0;
    final p = item['protein_g'] ?? 0;
    final c = item['carbs_g'] ?? 0;
    final f = item['fat_g'] ?? 0;
    final grams = item['grams'];
    final ingredients = item['ingredients'];
    final ingList = ingredients is List
        ? ingredients
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList()
        : <Map<String, dynamic>>[];
    final macros =
        "${t.translate("diet_kcal_label")} $kcal • "
        "${t.translate("diet_p_short")} $p • "
        "${t.translate("diet_c_short")} $c • "
        "${t.translate("diet_f_short")} $f"
        "${grams != null ? " • ${grams}g" : ""}";

    return Container(
      padding: TaqaUiScale.insetsLTRB(14, 10, 14, 15),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w700,
              height: 21 / 15,
              letterSpacing: 0,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(8)),
          Text(
            macros,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w400,
              height: 21 / 15,
              letterSpacing: 0,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
          if (ingList.isNotEmpty) ...[
            SizedBox(height: TaqaUiScale.h(4)),
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
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(13),
                fontWeight: FontWeight.w400,
                height: 18 / 13,
                letterSpacing: 0,
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
