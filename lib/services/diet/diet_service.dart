import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import 'diet_meals_storage.dart';
import 'diet_targets_storage.dart';

class DietService {
  static String baseUrl = ApiConfig.baseUrl;

  /// Set by Diet page so it can refresh when surplus is updated (submitBurn + fetchCurrentTargets).
  static void Function()? onTargetsUpdatedAfterBurn;

  /// Call after updating today's burn so the Diet page refreshes targets/meals if visible.
  static void notifyTargetsUpdatedAfterBurn() {
    onTargetsUpdatedAfterBurn?.call();
  }

  /// Generates diet targets for a user and persists them on the backend.
  /// Returns the generated targets JSON (and caches it locally).
  static Future<Map<String, dynamic>> generateTargets(int userId) async {
    final url = Uri.parse('$baseUrl/diet/generate/$userId');
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.post(url, headers: headers);

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode == 200) {
      if (response.body.isEmpty) {
        // Backend should return JSON; keep a safe fallback.
        return <String, dynamic>{};
      }
      final parsed = json.decode(response.body) as Map<String, dynamic>;
      try {
        await DietTargetsStorage.saveTargets(parsed);
      } catch (_) {
        // Ignore cache errors
      }
      return parsed;
    }

    if (response.statusCode == 400 || response.statusCode == 404) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Diet generation failed');
    }

    throw Exception('Unexpected error (${response.statusCode})');
  }

  /// Fetch current diet targets from backend and cache them locally.
  /// Backend returns targets for "today" including surplus from calories burned.
  static Future<Map<String, dynamic>> fetchCurrentTargets(int userId) async {
    final url = Uri.parse('$baseUrl/diet/current/$userId');
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.get(url, headers: headers);

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to load diet targets');
    }

    final targets = json.decode(response.body) as Map<String, dynamic>;
    try {
      await DietTargetsStorage.saveTargets(targets);
    } catch (_) {
      // Ignore cache errors
    }
    return targets;
  }

  /// Fetch current diet targets from cache (for offline use)
  static Future<Map<String, dynamic>?> fetchCurrentTargetsFromCache() async {
    return await DietTargetsStorage.loadTargets();
  }

  static String _dateParam(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  /// Ensures Meal 1..N exists for a given date (based on questionnaire meals_per_day).
  static Future<Map<String, dynamic>> openMealsForDate(
    int userId, {
    DateTime? date,
  }) async {
    final d = date ?? DateTime.now();
    final url = Uri.parse('$baseUrl/diet/meals/open/$userId?meal_date=${_dateParam(d)}');
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.post(url, headers: headers);

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to open meals');
    }

    final parsed = json.decode(response.body) as Map<String, dynamic>;
    try {
      await DietMealsStorage.saveMealsForDate(d, parsed);
    } catch (_) {
      // Ignore cache errors
    }
    return parsed;
  }

  /// Fetch meals for a date. If autoOpen=true, backend will create Meal 1..N if missing.
  static Future<Map<String, dynamic>> fetchMealsForDate(
    int userId, {
    DateTime? date,
    bool autoOpen = true,
    int? trainingDayId,
  }) async {
    final d = date ?? DateTime.now();
    final qp = <String, String>{
      'meal_date': _dateParam(d),
      'auto_open': autoOpen.toString(),
      if (trainingDayId != null) 'training_day_id': trainingDayId.toString(),
    };
    final url = Uri.parse('$baseUrl/diet/meals/$userId').replace(queryParameters: qp);
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.get(url, headers: headers);

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to load meals');
    }

    final parsed = json.decode(response.body) as Map<String, dynamic>;
    try {
      await DietMealsStorage.saveMealsForDate(d, parsed, trainingDayId: trainingDayId);
    } catch (_) {
      // Ignore cache errors
    }
    return parsed;
  }

  /// Add one extra meal slot for a specific date (questionnaire meals_per_day unchanged).
  /// Returns the full meals list for that day (same shape as fetchMealsForDate).
  /// Throws with message on 400 (max 10 meals) or 403.
  static Future<Map<String, dynamic>> addMealSlot({
    required int userId,
    DateTime? date,
  }) async {
    final d = date ?? DateTime.now();
    final qp = <String, String>{
      'meal_date': _dateParam(d),
    };
    final url = Uri.parse('$baseUrl/diet/meals/$userId/add').replace(queryParameters: qp);
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.post(url, headers: headers);

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode == 400 || response.statusCode == 403) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      final detail = body is Map ? (body['detail'] ?? body['message'])?.toString() : null;
      throw Exception(detail ?? (response.statusCode == 400 ? 'Maximum 10 meals per day.' : 'Not allowed'));
    }
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to add meal slot');
    }

    final parsed = json.decode(response.body) as Map<String, dynamic>;
    try {
      await DietMealsStorage.saveMealsForDate(d, parsed);
    } catch (_) {
      // Ignore cache errors
    }
    return parsed;
  }

  /// Create a custom meal for a given date (manual add meal widget).
  /// When [trainingDayId] is set, the meal is created for that training day (same as fetch).
  static Future<Map<String, dynamic>> createMeal({
    required int userId,
    required DateTime date,
    String? title,
    int? trainingDayId,
  }) async {
    final qp = <String, String>{
      'meal_date': _dateParam(date),
      if (trainingDayId != null) 'training_day_id': trainingDayId.toString(),
    };
    final url = Uri.parse('$baseUrl/diet/meals/$userId').replace(queryParameters: qp);
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode({
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      }),
    );

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to create meal');
    }

    return response.body.isNotEmpty
        ? (json.decode(response.body) as Map<String, dynamic>)
        : <String, dynamic>{};
  }

  /// Delete a meal (and its items) for a given meal id.
  static Future<Map<String, dynamic>> deleteMeal({
    required int userId,
    required int mealId,
    int? trainingDayId,
  }) async {
    final qp = <String, String>{
      'meal_id': mealId.toString(),
      if (trainingDayId != null) 'training_day_id': trainingDayId.toString(),
    };
    final url = Uri.parse('$baseUrl/diet/meals/$userId').replace(queryParameters: qp);
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.delete(url, headers: headers);

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to delete meal');
    }

    return response.body.isNotEmpty
        ? (json.decode(response.body) as Map<String, dynamic>)
        : <String, dynamic>{};
  }

  /// Delete a single item from a meal.
  static Future<void> deleteMealItem({
    required int userId,
    required int mealItemId,
  }) async {
    final headers = await AccountStorage.getAuthHeaders();

    // Primary path: /diet/meals/{user_id}/{meal_item_id}
    var response = await http.delete(
      Uri.parse('$baseUrl/diet/meals/$userId/$mealItemId'),
      headers: headers,
    );
    if (response.statusCode == 404) {
      // Fallback path: /diet/meals/{user_id}/items/{meal_item_id}
      response = await http.delete(
        Uri.parse('$baseUrl/diet/meals/$userId/items/$mealItemId'),
        headers: headers,
      );
    }

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to delete meal item');
    }
  }

  static Future<Map<String, dynamic>?> fetchMealsForDateFromCache(
    DateTime date, {
    int? trainingDayId,
  }) async {
    return await DietMealsStorage.loadMealsForDate(date, trainingDayId: trainingDayId);
  }

  /// Add an item to a meal from nutrition_foods_master (grams required).
  static Future<Map<String, dynamic>> addItemFromFoodsMaster({
    required int userId,
    required int mealId,
    required int foodId,
    required double grams,
    int? trainingDayId,
  }) async {
    final url = Uri.parse('$baseUrl/diet/meals/$userId/items/search/foods-master');
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode({
        'meal_id': mealId,
        'food_id': foodId,
        'grams': grams,
        if (trainingDayId != null) 'training_day_id': trainingDayId,
      }),
    );

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to add item');
    }

    return response.body.isNotEmpty
        ? (json.decode(response.body) as Map<String, dynamic>)
        : <String, dynamic>{};
  }

  /// Add an item to a meal from nutrition_local_restaurants (quantity required).
  static Future<Map<String, dynamic>> addItemFromRestaurants({
    required int userId,
    required int mealId,
    required int restaurantItemId,
    required int quantity,
    int? trainingDayId,
  }) async {
    final url = Uri.parse('$baseUrl/diet/meals/$userId/items/search/restaurants');
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode({
        'meal_id': mealId,
        'restaurant_item_id': restaurantItemId,
        'quantity': quantity,
        if (trainingDayId != null) 'training_day_id': trainingDayId,
      }),
    );

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to add item');
    }

    return response.body.isNotEmpty
        ? (json.decode(response.body) as Map<String, dynamic>)
        : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> fetchDaySummary(
    int userId, {
    DateTime? date,
    int? trainingDayId,
  }) async {
    final d = date ?? DateTime.now();
    final qp = <String, String>{
      'meal_date': _dateParam(d),
      if (trainingDayId != null) 'training_day_id': trainingDayId.toString(),
    };
    final url = Uri.parse('$baseUrl/diet/day-summary/$userId').replace(queryParameters: qp);
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.get(url, headers: headers);
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to load day summary');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchRemainingRecommendations(
    int userId, {
    DateTime? date,
    int? trainingDayId,
  }) async {
    final d = date ?? DateTime.now();
    final qp = <String, String>{
      'meal_date': _dateParam(d),
      if (trainingDayId != null) 'training_day_id': trainingDayId.toString(),
    };
    final url = Uri.parse('$baseUrl/diet/recommendations/$userId/remaining')
        .replace(queryParameters: qp);
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.get(url, headers: headers);
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to load recommendations');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> captureDaySummary(
    int userId, {
    DateTime? date,
    int? trainingDayId,
  }) async {
    final d = date ?? DateTime.now();
    final qp = <String, String>{
      'meal_date': _dateParam(d),
      if (trainingDayId != null) 'training_day_id': trainingDayId.toString(),
    };
    final url = Uri.parse('$baseUrl/diet/day-summary/$userId/capture').replace(queryParameters: qp);
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.post(url, headers: headers);
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to freeze day');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// Save a manual entry: one meal made only of ingredients.
  /// Each ingredient has its own name and macros; optional meal_name updates the meal slot title.
  /// [ingredients] must have at least one item; each: ingredient_name, calories, protein_g, carbs_g, fat_g; optional grams, food_id.
  static Future<Map<String, dynamic>> saveManualEntry({
    required int userId,
    required int mealId,
    String? mealName,
    required List<Map<String, dynamic>> ingredients,
    int? trainingDayId,
  }) async {
    if (ingredients.isEmpty) {
      throw Exception('At least one ingredient is required');
    }
    final url = Uri.parse('$baseUrl/diet/meals/$userId/items/manual');
    final body = <String, dynamic>{
      'meal_id': mealId,
      if (mealName != null && mealName.trim().isNotEmpty) 'meal_name': mealName.trim(),
      'ingredients': ingredients,
      if (trainingDayId != null) 'training_day_id': trainingDayId,
    };
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode(body),
    );

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final respBody = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(respBody['detail'] ?? 'Failed to save manual entry');
    }

    return response.body.isNotEmpty
        ? (json.decode(response.body) as Map<String, dynamic>)
        : <String, dynamic>{};
  }

  /// Update a meal: title, notes and/or totals_override.
  /// [totalsOverride] when set must include all four: calories, protein_g, carbs_g, fat_g (int or null). Send all null to clear override.
  static Future<Map<String, dynamic>> updateMeal({
    required int userId,
    required int mealId,
    String? title,
    String? notes,
    Map<String, int?>? totalsOverride,
    int? trainingDayId,
  }) async {
    final url = Uri.parse('$baseUrl/diet/meals/$userId');
    final body = <String, dynamic>{
      'meal_id': mealId,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (totalsOverride != null) 'totals_override': totalsOverride,
      if (trainingDayId != null) 'training_day_id': trainingDayId,
    };
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
    final response = await http.patch(
      url,
      headers: headers,
      body: json.encode(body),
    );

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final respBody = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(respBody['detail'] ?? 'Failed to update meal');
    }

    return response.body.isNotEmpty
        ? (json.decode(response.body) as Map<String, dynamic>)
        : <String, dynamic>{};
  }

  /// Preview a manual item from Foods Master (returns macros for grams).
  static Future<Map<String, dynamic>> previewManualItemFromFoodsMaster({
    required int userId,
    required int foodId,
    required double grams,
  }) async {
    final url = Uri.parse('$baseUrl/diet/meals/$userId/items/manual/preview/foods-master');
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode({
        'food_id': foodId,
        'grams': grams,
      }),
    );

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to preview food');
    }

    return response.body.isNotEmpty
        ? (json.decode(response.body) as Map<String, dynamic>)
        : <String, dynamic>{};
  }

  /// Add ingredients to an existing meal item.
  static Future<Map<String, dynamic>> addIngredientsToMealItem({
    required int userId,
    required int mealItemId,
    required List<Map<String, dynamic>> ingredients,
  }) async {
    final url = Uri.parse('$baseUrl/diet/meals/$userId/items/$mealItemId/ingredients');
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode({'ingredients': ingredients}),
    );

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to add ingredients');
    }

    return response.body.isNotEmpty
        ? (json.decode(response.body) as Map<String, dynamic>)
        : <String, dynamic>{};
  }

  /// Create a favorite meal from current meal items.
  static Future<Map<String, dynamic>> createFavoriteMeal({
    required int userId,
    required String mealName,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final url = Uri.parse('$baseUrl/diet/favorites/$userId');
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode({
        'meal_name': mealName,
        if (notes != null) 'notes': notes,
        'items': items,
      }),
    );

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to save favorite');
    }

    return response.body.isNotEmpty
        ? (json.decode(response.body) as Map<String, dynamic>)
        : <String, dynamic>{};
  }

  /// Fetch favorite meals list.
  static Future<List<Map<String, dynamic>>> fetchFavoriteMeals(int userId) async {
    final url = Uri.parse('$baseUrl/diet/favorites/$userId');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to load favorites');
    }

    final decoded = response.body.isNotEmpty ? json.decode(response.body) : {};

    // Expected backend shape:
    // {
    //   "user_id": 88,
    //   "favorite_meals": [ { id, meal_name, item_count, ... }, ... ]
    // }
    if (decoded is Map && decoded['favorite_meals'] is List) {
      final list = decoded['favorite_meals'] as List;
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }

    // Fallbacks for other shapes (defensive)
    if (decoded is List) {
      return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    if (decoded is Map && decoded['id'] != null && decoded['meal_name'] != null) {
      return [decoded.cast<String, dynamic>()];
    }

    return const <Map<String, dynamic>>[];
  }

  /// Fetch favorite meal details.
  static Future<Map<String, dynamic>> fetchFavoriteMealDetail({
    required int userId,
    required int favoriteMealId,
  }) async {
    final url = Uri.parse('$baseUrl/diet/favorites/$userId/$favoriteMealId');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to load favorite');
    }

    return response.body.isNotEmpty
        ? (json.decode(response.body) as Map<String, dynamic>)
        : <String, dynamic>{};
  }

  /// Log a favorite meal into a target meal slot.
  static Future<Map<String, dynamic>> logFavoriteMeal({
    required int userId,
    required int favoriteMealId,
    required int mealId,
    int? trainingDayId,
  }) async {
    final url = Uri.parse('$baseUrl/diet/favorites/$userId/$favoriteMealId/log');
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode({
        'meal_id': mealId,
        if (trainingDayId != null) 'training_day_id': trainingDayId,
      }),
    );

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to log favorite');
    }

    return response.body.isNotEmpty
        ? (json.decode(response.body) as Map<String, dynamic>)
        : <String, dynamic>{};
  }

  /// Add an item to a meal from a photo (Gemini estimation).
  /// Multipart form-data:
  /// - meal_id (required)
  /// - photo (required, image/*)
  /// - text_description (optional)
  /// - training_day_id (optional)
  static Future<Map<String, dynamic>> addItemFromPhoto({
    required int userId,
    required int mealId,
    required List<int> photoBytes,
    required String filename,
    String? textDescription,
    int? trainingDayId,
  }) async {
    final url = Uri.parse('$baseUrl/diet/meals/$userId/items/photo');
    final req = http.MultipartRequest('POST', url);
    final auth = await AccountStorage.getAuthHeaders();
    req.headers.addAll(auth);

    req.fields['meal_id'] = mealId.toString();
    final desc = (textDescription ?? '').trim();
    if (desc.isNotEmpty) req.fields['text_description'] = desc;
    if (trainingDayId != null) req.fields['training_day_id'] = trainingDayId.toString();

    // Do not set Content-Type header manually; MultipartRequest sets boundary.
    req.files.add(
      http.MultipartFile.fromBytes('photo', photoBytes, filename: filename),
    );

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    await AccountStorage.handle401(streamed.statusCode);
    if (streamed.statusCode != 200) {
      final decoded = body.isNotEmpty ? json.decode(body) : {};
      throw Exception((decoded is Map && decoded['detail'] != null) ? decoded['detail'] : 'Failed to add photo item');
    }

    return body.isNotEmpty ? (json.decode(body) as Map<String, dynamic>) : <String, dynamic>{};
  }
}
