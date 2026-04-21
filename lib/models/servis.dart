class Servis {
  final int id;
  final String ad;
  final bool aktif;
  final int min;
  final int max;
  final double fiyat;

  const Servis({
    required this.id,
    required this.ad,
    required this.aktif,
    required this.min,
    required this.max,
    required this.fiyat,
  });

  Servis copyWith({
    int? id,
    String? ad,
    bool? aktif,
    int? min,
    int? max,
    double? fiyat,
  }) {
    return Servis(
      id: id ?? this.id,
      ad: ad ?? this.ad,
      aktif: aktif ?? this.aktif,
      min: min ?? this.min,
      max: max ?? this.max,
      fiyat: fiyat ?? this.fiyat,
    );
  }
}
