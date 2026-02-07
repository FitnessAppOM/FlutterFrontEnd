import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import 'diet_meals_storage.dart';
import 'diet_targets_storage.dart';

class DietService {
  static String baseUrl = ApiConfig.baseUrl;

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
  static Future<Map<String, dynamic>> fetchCurrentTargets(int userId) async {
    final url = Uri.parse('$baseUrl/diet/current/$userId');
    final response = await http.get(url);

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
    final response = await http.get(url);

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

  /// Create a custom meal for a given date (manual add meal widget).
  static Future<Map<String, dynamic>> createMeal({
    required int userId,
    required DateTime date,
    String? title,
  }) async {
    final url = Uri.parse('$baseUrl/diet/meals/$userId')
        .replace(queryParameters: {'meal_date': _dateParam(date)});
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
    final response = await http.get(url);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to load day summary');
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

  /// Add a manual item to a meal (user enters name and macros directly).
  static Future<Map<String, dynamic>> addManualItem({
    required int userId,
    required int mealId,
    required String itemName,
    required int calories,
    required int proteinG,
    required int carbsG,
    required int fatG,
    double? grams,
    List<Map<String, dynamic>>? ingredients,
    int? trainingDayId,
  }) async {
    final url = Uri.parse('$baseUrl/diet/meals/$userId/items/manual');
    final body = <String, dynamic>{
      'meal_id': mealId,
      'item_name': itemName,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      if (grams != null) 'grams': grams,
      if (ingredients != null && ingredients.isNotEmpty) 'ingredients': ingredients,
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
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Failed to add manual item');
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

