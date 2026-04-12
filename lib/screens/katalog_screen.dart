import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/kategori.dart';
import '../models/servis.dart';
import '../widgets/kategori_tile.dart';
import '../widgets/servis_row.dart';

enum _KatalogSegment { kategoriler, servisler }

enum _KatalogSortMode { alphabetic, byId }

enum _KatalogFixOption {
  deleteEmptyCategories,
  hidePassiveServices,
  recalculatePrices,
}

class KatalogScreen extends StatefulWidget {
  const KatalogScreen({super.key});

  @override
  KatalogScreenState createState() => KatalogScreenState();
}

class KatalogScreenState extends State<KatalogScreen> {
  late final TextEditingController _searchController;
  late List<Kategori> _kategoriler;
  final Set<int> _gizliKategoriIdleri = <int>{};

  _KatalogSegment _segment = _KatalogSegment.kategoriler;
  _KatalogSortMode _sortMode = _KatalogSortMode.byId;
  String _arama = '';
  bool _pasifServisleriGizle = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _kategoriler = _buildMockKategoriler();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> refreshMockData({bool showMessage = true}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    final fresh = _buildMockKategoriler();
    final freshById = <int, Kategori>{
      for (final kategori in fresh) kategori.id: kategori,
    };
    final ordered = <Kategori>[];

    for (final mevcut in _kategoriler) {
      final next = freshById.remove(mevcut.id);
      if (next != null) {
        ordered.add(next);
      }
    }

    ordered.addAll(freshById.values);

    setState(() {
      _kategoriler = _reindexKategoriler(ordered);
      _gizliKategoriIdleri.removeWhere(
          (id) => !_kategoriler.any((kategori) => kategori.id == id));
    });

    if (showMessage && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Katalog mock verisi yenilendi.'),
          backgroundColor: context.catalogColors.activeGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.catalogColors;
    final filteredKategoriler = _filteredKategoriler;
    final filteredServisler = _filteredServisler;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.background),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              children: [
                _buildSearchField(colors),
                const SizedBox(height: 12),
                _buildSegmentControl(colors),
                const SizedBox(height: 12),
                _buildToolbar(
                  colors: colors,
                  kategoriCount: filteredKategoriler.length,
                  servisCount: filteredServisler.length,
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _segment == _KatalogSegment.kategoriler
                  ? _buildKategoriList(
                      key: const ValueKey<String>('kategoriler'),
                      kategoriler: filteredKategoriler,
                    )
                  : _buildServisList(
                      key: const ValueKey<String>('servisler'),
                      servisler: filteredServisler,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(CatalogThemeColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _arama = _normalizeText(value);
          });
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Kategori adı veya servis ID ara',
          hintStyle: const TextStyle(color: AppTheme.textMuted),
          prefixIcon: Icon(Icons.search_rounded, color: colors.accentBlue),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _arama = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: colors.accentBlue.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentControl(CatalogThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Kategoriler',
              selected: _segment == _KatalogSegment.kategoriler,
              selectedColor: colors.accentBlue,
              onTap: () {
                setState(() {
                  _segment = _KatalogSegment.kategoriler;
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegmentButton(
              label: 'Servisler',
              selected: _segment == _KatalogSegment.servisler,
              selectedColor: colors.accentBlue,
              onTap: () {
                setState(() {
                  _segment = _KatalogSegment.servisler;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar({
    required CatalogThemeColors colors,
    required int kategoriCount,
    required int servisCount,
  }) {
    final totalVisibleServiceCount = _visibleServiceTotalCount;
    final counterText = _segment == _KatalogSegment.kategoriler
        ? _arama.isEmpty
            ? '$kategoriCount kategori'
            : '$kategoriCount / ${_kategoriler.length} kategori'
        : _arama.isEmpty
            ? '$servisCount servis'
            : '$servisCount / $totalVisibleServiceCount servis';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;

        final actions = Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _ToolbarButton(
                label: 'Oto Sırala',
                icon: Icons.auto_fix_high_rounded,
                color: colors.activeGreen,
                onTap: _showActionBottomSheet,
              ),
              _ToolbarButton(
                label: 'Katalog Düzelt',
                icon: Icons.build_circle_rounded,
                color: colors.repairOrange,
                onTap: _showActionBottomSheet,
              ),
            ],
          ),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CounterPill(text: counterText, color: colors.accentBlue),
              const SizedBox(height: 10),
              actions,
            ],
          );
        }

        return Row(
          children: [
            _CounterPill(text: counterText, color: colors.accentBlue),
            const SizedBox(width: 12),
            Expanded(child: actions),
          ],
        );
      },
    );
  }

  Widget _buildKategoriList({
    required Key key,
    required List<Kategori> kategoriler,
  }) {
    if (kategoriler.isEmpty) {
      return _buildEmptyState(
        key: key,
        icon: Icons.category_rounded,
        title: 'Kategori bulunamadı',
        message: 'Arama kriterine uygun kategori veya servis ID eşleşmedi.',
      );
    }

    final shouldAllowReorder = _arama.isEmpty;

    final list = shouldAllowReorder
        ? ReorderableListView.builder(
            key: key,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            buildDefaultDragHandles: false,
            onReorder: _handleKategoriReorder,
            itemCount: kategoriler.length,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemBuilder: (context, index) {
              final kategori = kategoriler[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey<int>(kategori.id),
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: KategoriTile(
                    kategori: kategori,
                    filtrelenmisServisler:
                        _visibleServislerForCategory(kategori),
                    gorunur: !_gizliKategoriIdleri.contains(kategori.id),
                    onToggleVisibility: () =>
                        _toggleKategoriVisibility(kategori),
                    onEdit: () => _showEditCategorySheet(kategori),
                  ),
                ),
              );
            },
          )
        : ListView.builder(
            key: key,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: kategoriler.length,
            itemBuilder: (context, index) {
              final kategori = kategoriler[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: KategoriTile(
                  kategori: kategori,
                  filtrelenmisServisler: _visibleServislerForCategory(kategori),
                  gorunur: !_gizliKategoriIdleri.contains(kategori.id),
                  onToggleVisibility: () => _toggleKategoriVisibility(kategori),
                  onEdit: () => _showEditCategorySheet(kategori),
                ),
              );
            },
          );

    return RefreshIndicator(
      onRefresh: () => refreshMockData(showMessage: false),
      color: context.catalogColors.accentBlue,
      child: list,
    );
  }

  Widget _buildServisList({
    required Key key,
    required List<_ServisListeElemani> servisler,
  }) {
    if (servisler.isEmpty) {
      return _buildEmptyState(
        key: key,
        icon: Icons.search_off_rounded,
        title: 'Servis bulunamadı',
        message: 'Aktif filtrelerle eşleşen servis görünmüyor.',
      );
    }

    return RefreshIndicator(
      key: key,
      onRefresh: () => refreshMockData(showMessage: false),
      color: context.catalogColors.accentBlue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: servisler.length,
        itemBuilder: (context, index) {
          return ServisRow(
            servis: servisler[index].servis,
            variant: ServisRowVariant.card,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required Key key,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return ListView(
      key: key,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 360,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: AppTheme.textMuted),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Kategori> get _filteredKategoriler {
    if (_arama.isEmpty) {
      return _kategoriler;
    }

    return _kategoriler.where((kategori) {
      final kategoriMatch = _matchesCategoryName(kategori, _arama);
      final servisMatch = kategori.servisler.any((servis) {
        if (_pasifServisleriGizle && !servis.aktif) {
          return false;
        }
        return _matchesServis(servis, _arama);
      });
      return kategoriMatch || servisMatch;
    }).toList();
  }

  List<_ServisListeElemani> get _filteredServisler {
    final items = <_ServisListeElemani>[];

    for (final kategori in _kategoriler) {
      final kategoriMatch =
          _arama.isNotEmpty && _matchesCategoryName(kategori, _arama);

      for (final servis in kategori.servisler) {
        if (_pasifServisleriGizle && !servis.aktif) {
          continue;
        }

        if (_arama.isNotEmpty &&
            !(kategoriMatch || _matchesServis(servis, _arama))) {
          continue;
        }

        items.add(_ServisListeElemani(kategori: kategori, servis: servis));
      }
    }

    if (_sortMode == _KatalogSortMode.alphabetic) {
      items.sort((a, b) => a.servis.ad.compareTo(b.servis.ad));
    } else {
      items.sort((a, b) => a.servis.id.compareTo(b.servis.id));
    }

    return items;
  }

  List<Servis> _visibleServislerForCategory(Kategori kategori) {
    final categoryMatch =
        _arama.isNotEmpty && _matchesCategoryName(kategori, _arama);

    return kategori.servisler.where((servis) {
      if (_pasifServisleriGizle && !servis.aktif) {
        return false;
      }

      if (_arama.isEmpty || categoryMatch) {
        return true;
      }

      return _matchesServis(servis, _arama);
    }).toList();
  }

  int get _visibleServiceTotalCount => _kategoriler.fold<int>(
        0,
        (sum, kategori) =>
            sum +
            (_pasifServisleriGizle
                ? kategori.aktifServisSayisi
                : kategori.servisSayisi),
      );

  void _handleKategoriReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final moved = _kategoriler.removeAt(oldIndex);
      _kategoriler.insert(newIndex, moved);
      _kategoriler = _reindexKategoriler(_kategoriler);
    });
  }

  void _toggleKategoriVisibility(Kategori kategori) {
    final colors = context.catalogColors;
    final isCurrentlyVisible = !_gizliKategoriIdleri.contains(kategori.id);

    setState(() {
      if (isCurrentlyVisible) {
        _gizliKategoriIdleri.add(kategori.id);
      } else {
        _gizliKategoriIdleri.remove(kategori.id);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCurrentlyVisible
              ? '${kategori.ad} gizlendi.'
              : '${kategori.ad} tekrar görünür yapıldı.',
        ),
        backgroundColor:
            isCurrentlyVisible ? colors.passiveRed : colors.activeGreen,
      ),
    );
  }

  Future<void> _showEditCategorySheet(Kategori kategori) async {
    final colors = context.catalogColors;
    final controller = TextEditingController(text: kategori.ad);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kategori Düzenle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Mock veri üzerinde kategori adı güncellenir.',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Kategori adı',
                  prefixIcon: const Icon(Icons.edit_rounded),
                  filled: true,
                  fillColor: colors.background.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final yeniAd = controller.text.trim();
                    if (yeniAd.isEmpty) {
                      return;
                    }

                    setState(() {
                      _kategoriler = _kategoriler
                          .map(
                            (item) => item.id == kategori.id
                                ? item.copyWith(ad: yeniAd)
                                : item,
                          )
                          .toList();
                    });

                    Navigator.of(sheetContext).pop();
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Kaydet'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showActionBottomSheet() async {
    final colors = context.catalogColors;
    var selectedSort = _sortMode;
    final selectedFixes = <_KatalogFixOption>{
      if (_pasifServisleriGizle) _KatalogFixOption.hidePassiveServices,
    };

    final result = await showModalBottomSheet<_BottomSheetResult>(
      context: context,
      backgroundColor: colors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final isNarrow = MediaQuery.of(context).size.width < 420;

            return SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Oto Sırala ve Katalog Düzelt',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Sıralama tipini seç ve bakım adımlarını tek seferde uygula.',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MiniStatusPill(
                            label: selectedSort == _KatalogSortMode.alphabetic
                                ? 'Aktif: A-Z'
                                : 'Aktif: ID',
                            color: colors.accentBlue,
                            filled: true,
                          ),
                          _MiniStatusPill(
                            label: '${selectedFixes.length} bakım seçili',
                            color: colors.repairOrange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SheetSectionHeader(
                                title: 'Oto Sırala',
                                subtitle:
                                    'Katalog görünümünde kullanılacak ana sıra',
                                color: colors.activeGreen,
                              ),
                              const SizedBox(height: 12),
                              isNarrow
                                  ? Column(
                                      children: [
                                        _SheetOptionCard(
                                          label: 'A-Z harf sırası',
                                          subtitle:
                                              'Kategori ve servis adlarına göre alfabetik düzen',
                                          icon: Icons.sort_by_alpha_rounded,
                                          selected: selectedSort ==
                                              _KatalogSortMode.alphabetic,
                                          color: colors.activeGreen,
                                          onTap: () {
                                            setModalState(() {
                                              selectedSort =
                                                  _KatalogSortMode.alphabetic;
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        _SheetOptionCard(
                                          label: 'ID sırası',
                                          subtitle:
                                              'Kaynak servis kimliklerini temel alan teknik düzen',
                                          icon: Icons.tag_rounded,
                                          selected: selectedSort ==
                                              _KatalogSortMode.byId,
                                          color: colors.activeGreen,
                                          onTap: () {
                                            setModalState(() {
                                              selectedSort =
                                                  _KatalogSortMode.byId;
                                            });
                                          },
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: _SheetOptionCard(
                                            label: 'A-Z harf sırası',
                                            subtitle:
                                                'Kategori ve servis adlarına göre alfabetik düzen',
                                            icon: Icons.sort_by_alpha_rounded,
                                            selected: selectedSort ==
                                                _KatalogSortMode.alphabetic,
                                            color: colors.activeGreen,
                                            onTap: () {
                                              setModalState(() {
                                                selectedSort =
                                                    _KatalogSortMode.alphabetic;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _SheetOptionCard(
                                            label: 'ID sırası',
                                            subtitle:
                                                'Kaynak servis kimliklerini temel alan teknik düzen',
                                            icon: Icons.tag_rounded,
                                            selected: selectedSort ==
                                                _KatalogSortMode.byId,
                                            color: colors.activeGreen,
                                            onTap: () {
                                              setModalState(() {
                                                selectedSort =
                                                    _KatalogSortMode.byId;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                              const SizedBox(height: 22),
                              _SheetSectionHeader(
                                title: 'Katalog Düzelt',
                                subtitle:
                                    'Bakım araçları seçime göre birlikte çalışır',
                                color: colors.repairOrange,
                              ),
                              const SizedBox(height: 12),
                              _SheetToggleTile(
                                label: 'Boş kategorileri sil',
                                subtitle:
                                    'Hiç servisi kalmayan kategori kayıtlarını temizler',
                                selected: selectedFixes.contains(
                                  _KatalogFixOption.deleteEmptyCategories,
                                ),
                                color: colors.repairOrange,
                                icon: Icons.delete_sweep_rounded,
                                onTap: () {
                                  setModalState(() {
                                    _toggleFixSelection(
                                      selectedFixes,
                                      _KatalogFixOption.deleteEmptyCategories,
                                    );
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              _SheetToggleTile(
                                label: 'Pasif servisleri gizle',
                                subtitle:
                                    'Liste görünümünde aktif servisleri öne çıkarır',
                                selected: selectedFixes.contains(
                                  _KatalogFixOption.hidePassiveServices,
                                ),
                                color: colors.repairOrange,
                                icon: Icons.visibility_off_rounded,
                                onTap: () {
                                  setModalState(() {
                                    _toggleFixSelection(
                                      selectedFixes,
                                      _KatalogFixOption.hidePassiveServices,
                                    );
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              _SheetToggleTile(
                                label: 'Fiyatları yeniden hesapla',
                                subtitle:
                                    'Mock fiyatları güncel kurala göre yeniden üretir',
                                selected: selectedFixes.contains(
                                  _KatalogFixOption.recalculatePrices,
                                ),
                                color: colors.repairOrange,
                                icon: Icons.currency_lira_rounded,
                                onTap: () {
                                  setModalState(() {
                                    _toggleFixSelection(
                                      selectedFixes,
                                      _KatalogFixOption.recalculatePrices,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.accentBlue.withValues(alpha: 0.12),
                              Colors.white.withValues(alpha: 0.03),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.glassBorder),
                          boxShadow: [
                            BoxShadow(
                              color: colors.accentBlue.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${selectedFixes.length} bakım seçeneği · ${selectedSort == _KatalogSortMode.alphabetic ? 'A-Z' : 'ID'} sırası',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                _MiniStatusPill(
                                  label: 'Hazır',
                                  color: colors.activeGreen,
                                  filled: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Seçili işlemler tek adımda katalog listesine uygulanır.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.62),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop(
                                    _BottomSheetResult(
                                      sortMode: selectedSort,
                                      fixes: selectedFixes,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.auto_fix_high_rounded),
                                label: const Text('Uygula'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    _applyBottomSheetResult(result);
  }

  void _applyBottomSheetResult(_BottomSheetResult result) {
    var nextKategoriler = List<Kategori>.from(_kategoriler);
    final changeLog = <String>[];

    if (result.fixes.contains(_KatalogFixOption.deleteEmptyCategories)) {
      final removedCount = nextKategoriler
          .where((kategori) => kategori.servisSayisi == 0)
          .length;
      if (removedCount > 0) {
        nextKategoriler = nextKategoriler
            .where((kategori) => kategori.servisSayisi > 0)
            .toList();
        changeLog.add('$removedCount boş kategori silindi');
      }
    }

    if (result.fixes.contains(_KatalogFixOption.recalculatePrices)) {
      nextKategoriler = nextKategoriler
          .map(
            (kategori) => kategori.copyWith(
              servisler: kategori.servisler
                  .map(
                    (servis) => servis.copyWith(
                      fiyat: _recalculatePrice(servis),
                    ),
                  )
                  .toList(),
            ),
          )
          .map(_refreshCategoryMetrics)
          .toList();
      changeLog.add('Fiyatlar yeniden hesaplandı');
    }

    nextKategoriler = _sortKategoriler(nextKategoriler, result.sortMode);
    nextKategoriler = _reindexKategoriler(nextKategoriler);

    setState(() {
      _sortMode = result.sortMode;
      _pasifServisleriGizle =
          result.fixes.contains(_KatalogFixOption.hidePassiveServices);
      _kategoriler = nextKategoriler;
      _gizliKategoriIdleri.removeWhere(
          (id) => !_kategoriler.any((kategori) => kategori.id == id));
    });

    if (changeLog.isEmpty) {
      changeLog.add(
        result.sortMode == _KatalogSortMode.alphabetic
            ? 'A-Z sıralama uygulandı'
            : 'ID sıralama uygulandı',
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(changeLog.join(' · ')),
        backgroundColor: context.catalogColors.activeGreen,
      ),
    );
  }

  void _toggleFixSelection(
    Set<_KatalogFixOption> selectedFixes,
    _KatalogFixOption option,
  ) {
    if (selectedFixes.contains(option)) {
      selectedFixes.remove(option);
    } else {
      selectedFixes.add(option);
    }
  }

  List<Kategori> _sortKategoriler(
    List<Kategori> kategoriler,
    _KatalogSortMode mode,
  ) {
    final next = List<Kategori>.from(kategoriler);

    next.sort((a, b) {
      if (mode == _KatalogSortMode.alphabetic) {
        return a.ad.compareTo(b.ad);
      }
      return a.id.compareTo(b.id);
    });

    return next
        .map(
          (kategori) => kategori.copyWith(
            servisler: _sortServisler(kategori.servisler, mode),
          ),
        )
        .toList();
  }

  List<Servis> _sortServisler(List<Servis> servisler, _KatalogSortMode mode) {
    final next = List<Servis>.from(servisler);
    next.sort((a, b) {
      if (mode == _KatalogSortMode.alphabetic) {
        return a.ad.compareTo(b.ad);
      }
      return a.id.compareTo(b.id);
    });
    return next;
  }

  List<Kategori> _reindexKategoriler(List<Kategori> kategoriler) {
    return List<Kategori>.generate(
      kategoriler.length,
      (index) => _refreshCategoryMetrics(
        kategoriler[index].copyWith(siraNo: index + 1),
      ),
    );
  }

  Kategori _refreshCategoryMetrics(Kategori kategori) {
    final passiveCount =
        kategori.servisler.where((servis) => !servis.aktif).length;

    return kategori.copyWith(
      servisSayisi: kategori.servisler.length,
      pasifSayisi: passiveCount,
    );
  }

  bool _matchesCategoryName(Kategori kategori, String query) {
    return _normalizeText(kategori.ad).contains(query);
  }

  bool _matchesServis(Servis servis, String query) {
    return servis.id.toString().contains(query) ||
        _normalizeText(servis.ad).contains(query);
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .trim();
  }

  double _recalculatePrice(Servis servis) {
    final base = (servis.min * 0.0125) +
        (servis.max * 0.0018) +
        (servis.aktif ? 3.4 : 2.1) +
        ((servis.id % 11) * 0.37);
    return double.parse(base.toStringAsFixed(2));
  }

  List<Kategori> _buildMockKategoriler() {
    const platforms = <String>[
      'Instagram',
      'TikTok',
      'YouTube',
      'Telegram',
      'Facebook',
      'Spotify',
      'X',
      'Kick',
      'Discord',
      'Twitch',
      'LinkedIn',
    ];
    const serviceGroups = <String>[
      'Takipçi',
      'Beğeni',
      'İzlenme',
      'Yorum',
      'Kaydetme',
      'Abone',
      'Dinlenme',
      'Paylaşım',
      'Story',
      'Canlı Yayın',
    ];
    const labels = <String>[
      'Hızlı',
      'Premium',
      'Organik',
      'Global',
      'TR',
      'Kurumsal',
      'Keşfet',
      'Boost',
    ];
    const packageLabels = <String>[
      'Starter',
      'Gold',
      'Elite',
      'Express',
      'Mega',
      'Ultra',
      'Panel',
      'Plus',
    ];

    return List<Kategori>.generate(308, (index) {
      final id = index + 1;
      final categoryName =
          '${platforms[index % platforms.length]} ${serviceGroups[index % serviceGroups.length]} ${labels[index % labels.length]}';
      final shouldBeEmpty = index % 41 == 0;
      final serviceCount = shouldBeEmpty ? 0 : 6 + (index % 13);

      final servisler = List<Servis>.generate(serviceCount, (serviceIndex) {
        final serviceId = 1000 + (index * 37) + serviceIndex;
        final aktif = (serviceIndex + index) % 5 != 0;
        final min = 50 * ((serviceIndex % 4) + 1);
        final max = 1000 + ((serviceIndex % 5) * 500) + ((index % 4) * 250);
        final price = double.parse(
          (4.2 +
                  (index % 7) * 0.85 +
                  (serviceIndex % 6) * 0.55 +
                  (aktif ? 1.75 : 0.95))
              .toStringAsFixed(2),
        );

        return Servis(
          id: serviceId,
          ad: '$categoryName ${packageLabels[serviceIndex % packageLabels.length]} Paket ${serviceIndex + 1}',
          aktif: aktif,
          min: min,
          max: max,
          fiyat: price,
        );
      });

      final passiveCount = servisler.where((servis) => !servis.aktif).length;

      return Kategori(
        id: id,
        siraNo: id,
        ad: categoryName,
        servisSayisi: servisler.length,
        pasifSayisi: passiveCount,
        servisler: servisler,
      );
    });
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? selectedColor.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? selectedColor : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  final String text;
  final Color color;

  const _CounterPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _SheetSectionHeader({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _MiniStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const _MiniStatusPill({
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: filled ? 0.28 : 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? color : color.withValues(alpha: 0.86),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SheetOptionCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SheetOptionCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.08),
                  ]
                : [
                    AppTheme.glassBg,
                    Colors.white.withValues(alpha: 0.02),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                selected ? color.withValues(alpha: 0.4) : AppTheme.glassBorder,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (selected)
                        _MiniStatusPill(
                          label: 'Seçili',
                          color: color,
                          filled: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.74)
                          : AppTheme.textMuted,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color:
                  selected ? color : AppTheme.textMuted.withValues(alpha: 0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetToggleTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SheetToggleTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? [
                    color.withValues(alpha: 0.14),
                    color.withValues(alpha: 0.05),
                  ]
                : [
                    AppTheme.glassBg,
                    Colors.white.withValues(alpha: 0.015),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                selected ? color.withValues(alpha: 0.34) : AppTheme.glassBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 0.18 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _MiniStatusPill(
                        label: selected ? 'Açık' : 'Kapalı',
                        color: selected ? color : AppTheme.textMuted,
                        filled: selected,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? color : AppTheme.textMuted,
                  width: 1.4,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServisListeElemani {
  final Kategori kategori;
  final Servis servis;

  const _ServisListeElemani({
    required this.kategori,
    required this.servis,
  });
}

class _BottomSheetResult {
  final _KatalogSortMode sortMode;
  final Set<_KatalogFixOption> fixes;

  const _BottomSheetResult({
    required this.sortMode,
    required this.fixes,
  });
}
