import 'servis.dart';

class Kategori {
  final int id;
  final String ad;
  final List<Servis> servisler;
  final int siraNo;
  final int servisSayisi;
  final int pasifSayisi;

  const Kategori({
    required this.id,
    required this.ad,
    required this.servisler,
    this.siraNo = 0,
    this.servisSayisi = 0,
    this.pasifSayisi = 0,
  });

  int get aktifServisSayisi => servisler.where((s) => s.aktif).length;

  Kategori copyWith({
    int? id,
    String? ad,
    List<Servis>? servisler,
    int? siraNo,
    int? servisSayisi,
    int? pasifSayisi,
  }) {
    return Kategori(
      id: id ?? this.id,
      ad: ad ?? this.ad,
      servisler: servisler ?? this.servisler,
      siraNo: siraNo ?? this.siraNo,
      servisSayisi: servisSayisi ?? this.servisSayisi,
      pasifSayisi: pasifSayisi ?? this.pasifSayisi,
    );
  }
}
