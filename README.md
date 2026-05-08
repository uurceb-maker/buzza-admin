# Buzza Admin

Buzza altyapisini yonetmek icin gelistirilmis Flutter tabanli admin uygulamasi.
WordPress tarafindaki `buzza-admin` API'si ile haberlesir ve operasyonel islemleri tek panelden yonetir.

## Temel Ozellikler

- Site URL + admin giris
- Otomatik oturum acma (`remember_me`, token verify)
- Dashboard KPI kartlari ve gelir grafikleri
- Servis yonetimi (listeleme, aktif/pasif, senkronizasyon, siralama)
- Kategori yonetimi (duzenleme, bos kategori temizleme, siralama)
- Siparis yonetimi (durum guncelleme, iptal, detay)
- Kullanici yonetimi (bakiye guncelleme, oturum/log, engelleme, sifre sifirlama)
- Odeme talepleri onay/red
- Destek talepleri ve FreeScout gorunumu
- Guvenlik modulu (IP aksiyonlari, rate limit ayarlari, loglar)
- Genel ayarlar, hata logu ve "danger zone" islemleri

## Teknik Yapi

- Flutter + Dart
- State management: `provider`
- Ag istekleri: `http`
- Yerel saklama: `shared_preferences`
- Grafikler: `fl_chart`
- Platform destegi:
  - Android
  - iOS
  - Windows

## API Bagimliligi

Uygulama giriste verilen site URL'sinden su base path'i ureterek baglanir:

- `https://<site>/wp-json/buzza-admin/v1`

Ornek endpointler:

- `/auth/login`
- `/auth/verify`
- `/dashboard`
- `/services`, `/services/sync`, `/services/reorder`
- `/categories`, `/categories/reorder`, `/categories/delete-empty`
- `/orders`, `/orders/{id}/status`, `/orders/{id}/cancel`
- `/users`, `/users/{id}/detail`, `/users/{id}/balance`
- `/payments`, `/payments/{id}/action`
- `/tickets`, `/tickets/{id}/reply`
- `/security/*`
- `/settings`

Not: API tarafi aktif degilse veya URL yanlissa uygulama HTML donusunu algilayip hata mesaji verir.

## Kurulum

### Gereksinimler

- Flutter SDK (Dart 3.x)
- Android Studio veya Xcode
- Windows desktop icin Visual Studio (Desktop development with C++)

### Lokal calistirma

```bash
flutter pub get
flutter run
```

Belirli cihaz icin:

```bash
flutter run -d windows
flutter run -d android
```

## Build Alma

```bash
flutter build apk --release
flutter build ios --release
flutter build windows --release
```

## Cihaza Kurulum Adımları

### Android İçin Kurulum (Normal APK Yükleme)
Masaüstünüze kopyaladığınız veya derlediğiniz **.apk** dosyasını kullanarak Android cihazlara kurulum yapmak çok basittir:
1. **Dosyayı Telefa Gönderin:** APK dosyasını bilgisayardan telefonunuza gönderin (WhatsApp, Telegram, Google Drive, Mail veya USB kablosu ile).
2. **Dosyayı Açın:** Telefondaki Dosya Yöneticisi'ne girip indirdiğiniz `.apk` dosyasına dokunun.
3. **Bilinmeyen Kaynaklar İzni:** Ekrana "Güvenliğiniz için cihazınızın bilinmeyen kaynaklardan alınan uygulamaları yüklemesine izin verilmiyor" gibi bir uyarı çıkarsa: Ayarlar'a tıklayın, "Bu kaynaktan izin ver" (veya Bilinmeyen Kaynakları Yükle) seçeneğini aktif hale getirin.
4. **Kurulum:** Geri gelip "Yükle" butonuna basın. Kurulum bittiğinde uygulamanız ana ekrana gelecektir.

### iOS İçin Sideloadly ile Kurulum Adımları
*Önemli Not: iOS cihazlara kurulum yapabilmeniz için uygulamanın Apple formatı olan **.ipa** uzantılı dosyasına ihtiyacınız var. Aşağıdaki adımlar bir .ipa dosyanız olduğu varsayılarak yazılmıştır:*

1. **Gerekli Programları Kurun:** Bilgisayarınıza (Windows veya Mac) Sideloadly programını indirin ve kurun. Windows kullanıyorsanız, Sideloadly'nin çalışması için Apple'ın sitesinden iTunes ve iCloud'un kurulu olması gerekir.
2. **Telefonu Bilgisayara Bağlayın:** iPhone'unuzu kablo ile bilgisayara bağlayın. "Bu Bilgisayara Güven" uyarısı çıkarsa "Güven" diyerek şifrenizi girin.
3. **Sideloadly'i Çalıştırın ve Dosyayı Yükleyin:** Sideloadly programını açın. "Device" kısmında iPhone'unuzun göründüğünden emin olun. Elinizdeki **.ipa** dosyasını sürükleyip büyük IPA ikonunun üzerine bırakın.
4. **Apple Kimliğinizi Girin:** "Apple ID" kutucuğuna Apple e-posta adresinizi yazın. "Start" butonuna tıklayın. Sorulduğunda şifrenizi girip onaylayın. "Done." yazısını görene kadar bekleyin.
5. **Telefondan Uygulamaya Güven İzni Verme:** iPhone'da Ayarlar > Genel > VPN ve Aygıt Yönetimi kısmına gidin. "Geliştirici Uygulaması" altındaki e-posta adresinize tıklayın. "Güven [sizin e-postanız]" seçeneğine dokunun ve onaylayın.
6. **Geliştirici Modunu Açma (iOS 16+):** Ayarlar > Gizlilik ve Güvenlik > Geliştirici Modu menüsünden Geliştirici Modu'nu aktif hale getirin. Cihaz yeniden başlayacaktır.

## Kullanim Akisi

1. Uygulamayi ac, `Site URL`, `Kullanici Adi`, `Sifre` ile giris yap.
2. Dashboard'da anlik operasyon metriklerini kontrol et.
3. Sol menuden servis/kategori/siparis/kullanici/odeme/destek/guvenlik modullerine gec.
4. Ayarlar ekranindan senkronizasyon ve sistem parametrelerini yonet.
5. Cikis yaptiginda oturum bilgileri temizlenir; "Beni hatirla" aciksa tekrar giris kolaylasir.

## Proje Yapisi (Kisa)

- `lib/screens/tabs`: modul ekranlari
- `lib/services/admin_api.dart`: admin API katmani
- `lib/providers/auth_provider.dart`: oturum yonetimi
- `lib/config`: tema ve sabitler
- `lib/widgets`: ortak UI bilesenleri
