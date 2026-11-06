// category_repository.dart
//
// Static repository of word categories.
//
// Categories are defined in code rather than loaded from JSON because the
// list is small and stable, and because each category carries an
// `IconData` that must be a compile-time constant — something JSON cannot
// provide. If a user-editable category system is added later, only this
// file changes; no call-site references the raw list directly.
//
// All public members are synchronous. `getAll`, `getPlayable`, `findById`,
// and `contains` can be called from `build()` without introducing an async
// gap, so the Game Setup screen renders immediately with the category list
// already populated.
//
// The lists returned by `getAll` and `getPlayable` are cached, shared,
// unmodifiable views. Their identity is stable across calls, which lets
// Riverpod `select` callbacks and memoization treat them as equal without
// deep comparisons. Do not change them to return a fresh copy per call.
//
// The `custom` pseudo-category is the first entry in the underlying list so
// it naturally appears at the top of any straight iteration. Screens that
// render it as a separate full-width row at the bottom of the grid should
// filter it out via `getPlayable` rather than slicing by index — the
// pseudo-category is not a playable word source.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/word_category.dart';

class CategoryRepository {
  const CategoryRepository();

  /// Identifier of the pseudo-category that represents user-created words.
  ///
  /// Exposed publicly so call-sites can compare against it without
  /// duplicating the string literal.
  static const String customCategoryId = 'custom';

  /// Canonical list of all categories, including the `custom`
  /// pseudo-category at index 0.
  static const List<WordCategory> _categories = <WordCategory>[
    WordCategory(
      id: customCategoryId,
      englishName: 'Custom Word',
      nepaliName: 'अनुकूलित शब्द',
      icon: Icons.star_outline,
    ),
    WordCategory(
      id: 'animals',
      englishName: 'Animals',
      nepaliName: 'जनावरहरू',
      icon: Icons.pets,
    ),
    WordCategory(
      id: 'food',
      englishName: 'Food',
      nepaliName: 'खाना',
      icon: Icons.restaurant,
    ),
    WordCategory(
      id: 'places',
      englishName: 'Places',
      nepaliName: 'स्थानहरू',
      icon: Icons.place,
    ),
    WordCategory(
      id: 'professions',
      englishName: 'Professions',
      nepaliName: 'पेशाहरू',
      icon: Icons.work,
    ),
    WordCategory(
      id: 'sports',
      englishName: 'Sports',
      nepaliName: 'खेलकुद',
      icon: Icons.sports_soccer,
    ),
    WordCategory(
      id: 'vehicles',
      englishName: 'Vehicles',
      nepaliName: 'सवारी साधन',
      icon: Icons.directions_car,
    ),
    WordCategory(
      id: 'objects',
      englishName: 'Objects',
      nepaliName: 'वस्तुहरू',
      icon: Icons.inventory_2,
    ),
    WordCategory(
      id: 'school',
      englishName: 'School',
      nepaliName: 'विद्यालय',
      icon: Icons.school,
    ),
    WordCategory(
      id: 'technology',
      englishName: 'Technology',
      nepaliName: 'प्रविधि',
      icon: Icons.devices,
    ),
    WordCategory(
      id: 'clothing',
      englishName: 'Clothing',
      nepaliName: 'लुगाफाटो',
      icon: Icons.checkroom,
    ),
    WordCategory(
      id: 'body',
      englishName: 'Body',
      nepaliName: 'शरीर',
      icon: Icons.accessibility_new,
    ),
    WordCategory(
      id: 'nature',
      englishName: 'Nature',
      nepaliName: 'प्रकृति',
      icon: Icons.forest,
    ),
    WordCategory(
      id: 'entertainment',
      englishName: 'Entertainment',
      nepaliName: 'मनोरञ्जन',
      icon: Icons.theater_comedy,
    ),
    WordCategory(
      id: 'music',
      englishName: 'Music',
      nepaliName: 'संगीत',
      icon: Icons.music_note,
    ),
    WordCategory(
      id: 'brands',
      englishName: 'Brands',
      nepaliName: 'ब्रान्ड',
      icon: Icons.shopping_bag,
    ),
    WordCategory(
      id: 'celebrities',
      englishName: 'Celebrities',
      nepaliName: 'सेलिब्रिटी',
      icon: Icons.star,
    ),
    WordCategory(
      id: 'culture',
      englishName: 'Culture',
      nepaliName: 'संस्कृति',
      icon: Icons.museum,
    ),
    WordCategory(
      id: 'games',
      englishName: 'Games',
      nepaliName: 'गेमहरू',
      icon: Icons.sports_esports,
    ),
  ];

  /// Unmodifiable view over [_categories]. Cached so callers get a stable
  /// identity across calls.
  static final List<WordCategory> _allUnmodifiable =
  List<WordCategory>.unmodifiable(_categories);

  /// Unmodifiable view of every category except [customCategoryId].
  static final List<WordCategory> _playableUnmodifiable =
  List<WordCategory>.unmodifiable(
    _categories.where((WordCategory c) => c.id != customCategoryId),
  );

  /// Precomputed ID-to-category index for O(1) lookups.
  static final Map<String, WordCategory> _byId =
  _buildByIdIndex(_categories);

  static Map<String, WordCategory> _buildByIdIndex(
      List<WordCategory> list,
      ) {
    final Map<String, WordCategory> map = <String, WordCategory>{};
    for (final WordCategory c in list) {
      assert(
      !map.containsKey(c.id),
      'Duplicate category id "${c.id}" in CategoryRepository._categories',
      );
      map[c.id] = c;
    }
    return Map<String, WordCategory>.unmodifiable(map);
  }

  /// All categories, including the `custom` pseudo-category.
  ///
  /// Returns a cached, unmodifiable list whose identity is stable across
  /// calls.
  List<WordCategory> getAll() => _allUnmodifiable;

  /// Every category except the `custom` pseudo-category.
  ///
  /// Use this for anything that counts or renders selectable categories —
  /// the grid, the "N selected" summary, and the "Select All" action all
  /// need to exclude the pseudo-category.
  List<WordCategory> getPlayable() => _playableUnmodifiable;

  /// Returns the category with the given [id], or `null` if none exists.
  /// Constant-time lookup.
  WordCategory? findById(String id) => _byId[id];

  /// Whether a category with the given [id] exists. Constant-time lookup.
  bool contains(String id) => _byId.containsKey(id);
}

/// Provides the app-wide [CategoryRepository].
final categoryRepositoryProvider = Provider<CategoryRepository>(
      (ref) => const CategoryRepository(),
);

/// Provides the full category list, including the `custom` pseudo-category.
final allCategoriesProvider = Provider<List<WordCategory>>(
      (ref) => ref.watch(categoryRepositoryProvider).getAll(),
);

/// Provides only the playable categories, excluding the `custom`
/// pseudo-category.
///
/// Prefer this over inline filtering in widgets so the exclusion rule stays
/// in one place and the "N selected" counter always matches the rendered
/// grid.
final playableCategoriesProvider = Provider<List<WordCategory>>(
      (ref) => ref.watch(categoryRepositoryProvider).getPlayable(),
);