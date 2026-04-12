import 'package:flutter_test/flutter_test.dart';

import 'package:buzza_admin/services/catalog_sorter.dart';

void main() {
  group('CatalogSorter', () {
    test(
        'sorts categories by platform priority and pushes maintenance items last',
        () {
      final List<Map<String, dynamic>> categories = <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': 'Instagram Turk Organik Takipci'},
        <String, dynamic>{'id': 2, 'name': 'Bakim ve Test Servisleri'},
        <String, dynamic>{'id': 3, 'name': 'TikTok Begeni Hizmetleri'},
        <String, dynamic>{'id': 4, 'name': 'Instagram Turk Begeni'},
        <String, dynamic>{'id': 5, 'name': 'Spotify Premium'},
        <String, dynamic>{'id': 6, 'name': 'Discord Reaksiyon'},
        <String, dynamic>{'id': 7, 'name': 'Instagram Izlenme'},
        <String, dynamic>{'id': 8, 'name': 'Eski Kapali Kategoriler'},
        <String, dynamic>{'id': 9, 'name': 'X Takipci Servisleri'},
        <String, dynamic>{'id': 10, 'name': 'Instagram Yorum'},
      ];

      final List<Map<String, dynamic>> sorted =
          CatalogSorter.sortCategoryMaps(categories);

      expect(
        sorted.map((Map<String, dynamic> item) => item['name']).toList(),
        <String>[
          'Instagram Izlenme',
          'Instagram Turk Begeni',
          'Instagram Turk Organik Takipci',
          'Instagram Yorum',
          'TikTok Begeni Hizmetleri',
          'X Takipci Servisleri',
          'Spotify Premium',
          'Discord Reaksiyon',
          'Bakim ve Test Servisleri',
          'Eski Kapali Kategoriler',
        ],
      );
    });

    test('detects X platform only as a standalone token', () {
      expect(CatalogSorter.categoryPriority('X / Twitter Takipci'), 3);
      expect(CatalogSorter.categoryPriority('Mix Paketleri'), 9);
    });

    test('sorts services by type then turk organik premium and price', () {
      final List<Map<String, dynamic>> services = <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': 'Premium Begeni', 'price': 40},
        <String, dynamic>{'id': 2, 'name': 'Turk Begeni', 'price': 60},
        <String, dynamic>{'id': 3, 'name': 'Organik Begeni', 'price': 50},
        <String, dynamic>{'id': 4, 'name': 'Standart Begeni', 'price': 20},
        <String, dynamic>{'id': 5, 'name': 'Begeni Test', 'price': 1},
      ];

      final List<Map<String, dynamic>> sorted =
          CatalogSorter.sortServiceMaps(services);

      expect(
        sorted.map((Map<String, dynamic> item) => item['name']).toList(),
        <String>[
          'Turk Begeni',
          'Organik Begeni',
          'Premium Begeni',
          'Standart Begeni',
          'Begeni Test',
        ],
      );
    });

    test('falls back to alphabetical compare when price is missing', () {
      final List<Map<String, dynamic>> services = <Map<String, dynamic>>[
        <String, dynamic>{'id': 11, 'name': 'Yorum B'},
        <String, dynamic>{'id': 12, 'name': 'Yorum A'},
      ];

      final List<Map<String, dynamic>> sorted =
          CatalogSorter.sortServiceMaps(services);

      expect(
        sorted.map((Map<String, dynamic> item) => item['name']).toList(),
        <String>['Yorum A', 'Yorum B'],
      );
    });
  });
}
