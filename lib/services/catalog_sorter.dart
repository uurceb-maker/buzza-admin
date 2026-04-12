class CatalogSortNormalizer {
  const CatalogSortNormalizer._();

  static const Map<String, String> _charMap = <String, String>{
    'ı': 'i',
    'İ': 'i',
    'i̇': 'i',
    'ş': 's',
    'Ş': 's',
    'ğ': 'g',
    'Ğ': 'g',
    'ü': 'u',
    'Ü': 'u',
    'ö': 'o',
    'Ö': 'o',
    'ç': 'c',
    'Ç': 'c',
    'â': 'a',
    'î': 'i',
    'û': 'u',
    'Ä±': 'i',
    'Ä°': 'i',
    'ÅŸ': 's',
    'Å': 's',
    'ÄŸ': 'g',
    'Ä': 'g',
    'Ã¼': 'u',
    'Ãœ': 'u',
    'Ã¶': 'o',
    'Ã–': 'o',
    'Ã§': 'c',
    'Ã‡': 'c',
    'Ã¢': 'a',
    'Ã®': 'i',
    'Ã»': 'u',
  };

  static String normalize(String? value) {
    var text = (value ?? '').trim();
    if (text.isEmpty) return '';
    _charMap.forEach((String from, String to) {
      text = text.replaceAll(from, to);
    });
    text = text.toLowerCase();
    text = text.replaceAll(RegExp(r'[\/_\-]+'), ' ');
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  static List<String> tokenize(String? value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) return const <String>[];
    return normalized.split(' ');
  }

  static bool containsAny(String? value, Iterable<String> keywords) {
    final normalized = normalize(value);
    if (normalized.isEmpty) return false;
    for (final String keyword in keywords) {
      final needle = normalize(keyword);
      if (needle.isNotEmpty && normalized.contains(needle)) {
        return true;
      }
    }
    return false;
  }
}

class CatalogSorter {
  const CatalogSorter._();

  static const List<String> _categoryBottomKeywords = <String>[
    'bakim',
    'test',
    'deneme',
    'kapali',
    'maintenance',
    'gecici',
    'eski',
    'deactivated',
  ];

  static const List<String> _serviceBottomKeywords = <String>[
    'test',
    'deneme',
    'bakim',
    'eski',
    'kapali',
    'gecici',
    'inactive',
  ];

  static const Map<int, List<String>> _serviceTypeKeywords =
      <int, List<String>>{
    1: <String>['takipci', 'follower', 'follow', 'abone'],
    2: <String>['begeni', 'like'],
    3: <String>[
      'izlenme',
      'izleme',
      'views',
      'view',
      'watch',
      'stream',
      'dinleme'
    ],
    4: <String>['yorum', 'comment'],
    5: <String>['kaydet', 'save', 'paylasim', 'share', 'repost'],
    6: <String>['kesfet', 'explore', 'reaksiyon', 'reaction', 'emoji'],
    7: <String>['paket', 'kombo', 'bundle', 'set'],
  };

  static String normalizeText(String? value) =>
      CatalogSortNormalizer.normalize(value);

  static int categoryPriority(String? name) {
    final normalized = normalizeText(name);
    final tokens = CatalogSortNormalizer.tokenize(normalized);
    if (normalized.contains('instagram')) return 1;
    if (normalized.contains('tiktok')) return 2;
    if (tokens.contains('twitter') || tokens.contains('x')) return 3;
    if (tokens.contains('youtube') || tokens.contains('yt')) return 4;
    if (normalized.contains('facebook')) return 5;
    if (normalized.contains('spotify')) return 6;
    if (normalized.contains('telegram')) return 7;
    if (normalized.contains('discord')) return 8;
    return 9;
  }

  static int categoryBottomPriority(String? name) {
    return CatalogSortNormalizer.containsAny(name, _categoryBottomKeywords)
        ? 1
        : 0;
  }

  static int serviceTypePriority(String? name) {
    final normalized = normalizeText(name);
    for (final MapEntry<int, List<String>> entry
        in _serviceTypeKeywords.entries) {
      if (CatalogSortNormalizer.containsAny(normalized, entry.value)) {
        return entry.key;
      }
    }
    return 8;
  }

  static int serviceBottomPriority(String? name) {
    return CatalogSortNormalizer.containsAny(name, _serviceBottomKeywords)
        ? 1
        : 0;
  }

  static int serviceTurkPriority(String? name) {
    return CatalogSortNormalizer.containsAny(
            name, const <String>['turk', 'turkish'])
        ? 0
        : 1;
  }

  static int serviceOrganicPriority(String? name) {
    return CatalogSortNormalizer.containsAny(
            name, const <String>['organik', 'organic'])
        ? 0
        : 1;
  }

  static int servicePremiumPriority(String? name) {
    return CatalogSortNormalizer.containsAny(name, const <String>['premium'])
        ? 0
        : 1;
  }

  static List<Map<String, dynamic>> sortCategoryMaps(
    Iterable<Map<String, dynamic>> categories,
  ) {
    final List<Map<String, dynamic>> items = categories
        .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
        .toList();
    items.sort(_compareCategoryMaps);
    return items;
  }

  static List<Map<String, dynamic>> sortServiceMaps(
    Iterable<Map<String, dynamic>> services, {
    Iterable<Map<String, dynamic>> categories = const <Map<String, dynamic>>[],
  }) {
    final List<Map<String, dynamic>> items = services
        .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
        .toList();
    final Map<int, Map<String, dynamic>> categoryMap =
        <int, Map<String, dynamic>>{
      for (final Map<String, dynamic> category in categories)
        _readInt(category, const <String>['id']):
            Map<String, dynamic>.from(category),
    }..remove(0);

    items.sort((Map<String, dynamic> left, Map<String, dynamic> right) {
      final int categoryCompare =
          _compareServiceCategories(left, right, categoryMap: categoryMap);
      if (categoryCompare != 0) {
        return categoryCompare;
      }
      return _compareServiceMaps(left, right);
    });
    return items;
  }

  static int _compareCategoryMaps(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final String leftName = _readString(left, const <String>['name', 'ad']);
    final String rightName = _readString(right, const <String>['name', 'ad']);

    final int bottomCompare = categoryBottomPriority(leftName)
        .compareTo(categoryBottomPriority(rightName));
    if (bottomCompare != 0) return bottomCompare;

    final int priorityCompare =
        categoryPriority(leftName).compareTo(categoryPriority(rightName));
    if (priorityCompare != 0) return priorityCompare;

    final int nameCompare =
        normalizeText(leftName).compareTo(normalizeText(rightName));
    if (nameCompare != 0) return nameCompare;

    return _readInt(left, const <String>['id']).compareTo(
      _readInt(right, const <String>['id']),
    );
  }

  static int _compareServiceCategories(
    Map<String, dynamic> left,
    Map<String, dynamic> right, {
    required Map<int, Map<String, dynamic>> categoryMap,
  }) {
    final int leftCategoryId =
        _readInt(left, const <String>['category_id', 'categoryId']);
    final int rightCategoryId =
        _readInt(right, const <String>['category_id', 'categoryId']);

    final String leftCategoryName =
        _serviceCategoryName(left, categoryMap[leftCategoryId]);
    final String rightCategoryName =
        _serviceCategoryName(right, categoryMap[rightCategoryId]);

    if (leftCategoryName.isEmpty && rightCategoryName.isEmpty) {
      return leftCategoryId.compareTo(rightCategoryId);
    }

    final int compare = _compareCategoryMaps(
      <String, dynamic>{'id': leftCategoryId, 'name': leftCategoryName},
      <String, dynamic>{'id': rightCategoryId, 'name': rightCategoryName},
    );
    if (compare != 0) return compare;

    return leftCategoryId.compareTo(rightCategoryId);
  }

  static int _compareServiceMaps(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final String leftName = _serviceDisplayName(left);
    final String rightName = _serviceDisplayName(right);

    final List<int> leadingComparisons = <int>[
      serviceBottomPriority(leftName)
          .compareTo(serviceBottomPriority(rightName)),
      serviceTypePriority(leftName).compareTo(serviceTypePriority(rightName)),
      serviceTurkPriority(leftName).compareTo(serviceTurkPriority(rightName)),
      serviceOrganicPriority(leftName)
          .compareTo(serviceOrganicPriority(rightName)),
      servicePremiumPriority(leftName)
          .compareTo(servicePremiumPriority(rightName)),
    ];

    for (final int comparison in leadingComparisons) {
      if (comparison != 0) {
        return comparison;
      }
    }

    final double? leftPrice = _serviceRate(left);
    final double? rightPrice = _serviceRate(right);
    if (leftPrice != null && rightPrice != null && leftPrice != rightPrice) {
      return leftPrice.compareTo(rightPrice);
    }

    final int nameCompare =
        normalizeText(leftName).compareTo(normalizeText(rightName));
    if (nameCompare != 0) return nameCompare;

    final String leftProvider =
        _readString(left, const <String>['provider_service_id']);
    final String rightProvider =
        _readString(right, const <String>['provider_service_id']);
    if (leftProvider != rightProvider) {
      return leftProvider.compareTo(rightProvider);
    }

    return _readInt(left, const <String>['id']).compareTo(
      _readInt(right, const <String>['id']),
    );
  }

  static String _serviceDisplayName(Map<String, dynamic> service) {
    final bool isOverridden = _readBool(
      service,
      const <String>['is_name_overridden', 'isNameOverridden'],
    );
    final String overrideName =
        _readString(service, const <String>['name_override', 'nameOverride']);
    if (isOverridden && overrideName.isNotEmpty) {
      return overrideName;
    }
    return _readString(service, const <String>['name', 'ad']);
  }

  static String _serviceCategoryName(
    Map<String, dynamic> service,
    Map<String, dynamic>? category,
  ) {
    final String direct = _readString(
      service,
      const <String>['category_name', 'categoryName', 'category'],
    );
    if (direct.isNotEmpty) {
      return direct;
    }
    if (category == null) {
      return '';
    }
    return _readString(category, const <String>['name', 'ad']);
  }

  static double? _serviceRate(Map<String, dynamic> service) {
    for (final String key in const <String>[
      'rate_per_1k',
      'rate',
      'price',
      'fiyat',
      'original_rate_per_1k',
    ]) {
      final double? value = _readDoubleNullable(service[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  static bool _readBool(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = map[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      final String text = '$value'.trim().toLowerCase();
      if (text == '1' || text == 'true' || text == 'yes' || text == 'on') {
        return true;
      }
      if (text == '0' || text == 'false' || text == 'no' || text == 'off') {
        return false;
      }
    }
    return false;
  }

  static String _readString(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final String value = '${map[key] ?? ''}'.trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  static int _readInt(Map<String, dynamic> map, List<String> keys,
      [int fallback = 0]) {
    for (final String key in keys) {
      final dynamic value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final int? parsed = int.tryParse('${value ?? ''}'.trim());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static double? _readDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    final String text = '$value'.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }
}
