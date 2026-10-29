# CarPlay Tiyatro

CarPlay ekranında YouTube (ve deneysel olarak Netflix) oynatmak için bir iOS uygulaması (Xcode projesi).

## Önemli: Kısıtlar

- **App Store'a giremez.** Apple, CarPlay'de video oynatan uygulamalara izin vermiyor. Bu uygulama
  `com.apple.developer.carplay-maps` (navigasyon) yetkisini kullanarak araç ekranına kendi görünümünü
  çiziyor. CarTube gibi uygulamalar da bu yöntemi kullanıyor.
- **Gerçek cihazda** bu yetki provisioning profile'da bulunmalı. Apple bu yetkiyi yalnızca gerçek navigasyon
  uygulamalarına veriyor. Bu yüzden gerçek araçta çalıştırmanın yolları: TrollStore, jailbreak veya
  yetkinin profile eklenebildiği başka bir dağıtım yöntemi.
- **iOS Simülatöründe** yetki zorunlu tutulmuyor. Geliştirme ve test için bu yeterli (aşağıya bakın).
- **Netflix:** Netflix mobil tarayıcıda oynatmaya izin vermiyor. Uygulama masaüstü Safari gibi görünüyor ama
  FairPlay DRM ve Netflix'in kendi kısıtları yüzünden oynatma büyük olasılıkla başarısız olur ya da siyah ekran
  verir. YouTube sorunsuz çalışmalı.
- **Güvenlik:** Araç ~9 km/s'nin üstünde hareket ederken (GPS hızı) araç ekranındaki video kapatılır. Konum izni
  verilmezse video hiç gösterilmez. Ayarlardaki "Sürüşte sesi sürdür" seçeneği açıksa, sürüş sırasında
  yalnızca ses çalmaya devam eder.

## Gereksinimler

- Xcode 16 veya üstü (proje, senkronize klasör formatını kullanıyor)
- iOS 17+

## Çalıştırma (Simülatör + CarPlay)

1. `CarPlayTiyatro.xcodeproj` dosyasını açın.
2. Target → *Signing & Capabilities* bölümünde kendi Team'inizi seçin. Gerekirse
   `PRODUCT_BUNDLE_IDENTIFIER` değerini (`com.example.carplaytiyatro`) değiştirin.
3. Bir iPhone simülatöründe çalıştırın.
4. Simülatör menüsünden **I/O → External Displays → CarPlay** seçeneğini açın.
5. Telefonda YouTube'u açın, bir video seçin ve ekranı **Araç** olarak değiştirin.

## Nasıl çalışıyor?

| Dosya | Görevi |
|---|---|
| `Player/PlayerController.swift` | Tek bir `WKWebView`'i yönetir ve onu telefon ile CarPlay ekranı arasında taşır. JS ile oynat/duraklat/ileri-geri sarma kontrollerini sağlar. |
| `Player/PlayerScripts.swift` | Sayfaya enjekte edilen JavaScript: `<video>` öğesini bulur, durumunu bildirir ve "sinema modu"nda videoyu tam ekrana yayar. |
| `CarPlay/CarPlaySceneDelegate.swift` | CarPlay bağlantısını yönetir. `CPMapTemplate` düğmeleri: ⏪10, ▶︎/⏸, 10⏩, sinema modu, YouTube/Netflix, Geri, Telefona/Araca Al. |
| `CarPlay/CarPlayVideoViewController.swift` | `CPWindow`'un kök görünümü. Videoyu ve sürüş kilidi katmanını gösterir. |
| `Player/DrivingMonitor.swift` | GPS hızına göre aracın hareket edip etmediğini bildirir. |
| `Views/ContentView.swift` | Telefon arayüzü: servis seçimi, ekran seçimi ve kumanda. |

CarPlay ekranı dokunmatik girdiyi uygulamaya iletmediği için video seçimi ve arama telefonda yapılıyor. Video
araç ekranına gönderildikten sonra kontrol, araç ekranındaki düğmeler veya telefondaki kumanda ile sağlanıyor.
