# Hımbıl — Yapılması Gerekenler

> Bu liste, 8 Temmuz 2026 tarihli kapsamlı kod incelemesinin (mimari, güvenlik, UI/UX, test, DevOps) uygulanabilir iş maddelerine dökülmüş halidir. Her madde: **ne yapılacak → nerede → nasıl**. Sıra öncelik sırasıdır; 🔴 blok yayın engelidir. Bir madde tamamlandığında kutusunu işaretleyin.

---

## 🔴 1. Hemen düzeltilmesi gerekenler (yayın engelleri + adalet hataları)

- [ ] **1. Release imzasını gerçek keystore'a geçir** — [build.gradle.kts](../client-flutter/android/app/build.gradle.kts)
  `signingConfigs.release`, `key.properties` üzerinden okuyacak şekilde bağlandı (dosya yoksa debug anahtarına düşer) ve `android/key.properties.example` şablonu eklendi — bkz. içindeki `keytool` komutu. **Kalan iş (sen yapmalısın):** kendi makinende `keytool` ile gerçek keystore'u üret, `android/key.properties`'i doldur — bu üretim şifrelerini bir asistan terminaline geçirmek istemedim çünkü kalıcı Play Store imzalama sırrı.

- [x] **2. Ekran yönünü dikeye kilitle** — 3 dosya birden:
  - [main.dart](../client-flutter/lib/main.dart)'e `await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);` ekle (`services.dart` import'u ile),
  - [AndroidManifest.xml](../client-flutter/android/app/src/main/AndroidManifest.xml)'deki `<activity>`'ye `android:screenOrientation="portrait"` ekle,
  - [Info.plist](../client-flutter/ios/Runner/Info.plist)'te `UISupportedInterfaceOrientations` dizisinden Landscape girdilerini çıkar.
  Layout'lar portrait varsayıyor (bkz. `widget_test.dart` içindeki `_setPhoneSize` notu); yan çevrilince overflow oluşur.

- [x] **3. Oyun ekranına sistem geri tuşu koruması ekle** — [game_screen.dart:296](../client-flutter/lib/screens/game_screen.dart#L296)
  `Scaffold`'u `PopScope(canPop: false, onPopInvokedWithResult: ...)` ile sar, geri tuşunu mevcut `_confirmExitToMenu` diyaloğuna bağla. Şu an "< Menü" butonu onay soruyor ama Android geri tuşu onaysız atıyor — tur ve puanlar sessizce kayboluyor.

- [x] **4. Slam penceresi süre sızıntısını kapat** — [game_controller.dart:13-14](../client-flutter/lib/game/game_controller.dart#L13-L14)
  `swapTickDuration = 5.0` ve `slamWindowDuration = 4.0` farkı, sayacın "4.0'dan başladığını" gören oyuncuya pencerenin açıldığını söylüyor. İkisini eşitle (design referansı zaten 4 sn diyor: ikisi de `4.0` olsun).

- [x] **5. Seçili kartın slam penceresinde kalkık kalmasını düzelt** — [game_screen.dart:79](../client-flutter/lib/screens/game_screen.dart#L79)
  `_selectedIndex = null` ataması sadece `phase == 'swapping'` dalında; koşulu kaldırıp **her** faz değişiminde sıfırla. Mevcut halde pencere boyunca bir kart kalkık kalıyor, üstelik relay sonrası *yeni gelen* kart seçili görünüyor — hem görsel bug hem bilgi sızıntısı.

- [x] **6. Slam penceresinde kart etkileşimini görsel olarak canlı tut** — [game_screen.dart:197](../client-flutter/lib/screens/game_screen.dart#L197)
  `_onCardTapped` pencere sırasında sessizce ölüyor; bu da "pencere açık" sinyali. Tıklamada kartın seçilme animasyonunu göster ama `submitHumanChoice`'u yalnız `swapping` fazında çağır — dışarıdan iki faz ayırt edilemesin.

- [x] **7. Botlara "üstüne basma" (pile-on) davranışı ekle** — [game_controller.dart:159-163](../client-flutter/lib/game/game_controller.dart#L159-L163)
  Şu an sadece 4'lüsü olan botlar slam adayı; insan ise bot slam'ını görüp her tur bedava 75 puan toplayabiliyor. `_openSlamWindow`'da 4'lüsü olmayan botları da (örn. %60 olasılıkla, ilk basıştan 0.5–1.2 sn sonra tetiklenecek şekilde) aday yap — yarış simetrik olsun.

- [x] **8. Uygulama etiketini düzelt** — [AndroidManifest.xml:3](../client-flutter/android/app/src/main/AndroidManifest.xml#L3)
  `android:label="himbil"` → `android:label="Hımbıl"`. iOS tarafında `CFBundleDisplayName`'i de kontrol et.

---

## 🟠 2. Oyun ve ürün mantığında değiştirilmesi gerekenler

- [x] **9. Maç sonu jeton ödülü ekle** — [game_controller.dart:184-192](../client-flutter/lib/game/game_controller.dart#L184-L192) + [player_session.dart](../client-flutter/lib/session/player_session.dart)
  Ekonomi tek yönlü: 500 jetonla başlanıyor, kazanma yolu yok (900'lük "Elmas" asla alınamaz). Maç sonunda sıralamaya göre örn. 100/60/40/20 jeton yaz; `PlayerSession`'a `addTokens(int, String reason)` ekle.

- [x] **10. Mağazada satın alma onayı iste** — [store_tab.dart:158-166](../client-flutter/lib/widgets/store_tab.dart#L158-L166)
  Fiyat piline tek dokunuş anında satın alıp kuşanıyor; yanlış dokunuş jeton yakar. Araya küçük bir onay diyaloğu koy ("X'i 300 jetona satın al?").

- [x] **11. Sahte istatistik ve liderliği gerçeğe bağla** — [home_screen.dart:31-43](../client-flutter/lib/screens/home_screen.dart#L31-L43) ve [home_screen.dart:181-185](../client-flutter/lib/screens/home_screen.dart#L181-L185)
  "47 oyun / 19 galibiyet" ve "Deniz K. 2450" tamamen hardcoded. Maç sonuçlarını `PlayerSession`'a kaydedip gerçek yerel istatistik göster; liderlik tablosuna sunucu gelene kadar "Yakında" durumu koy.

- [x] **12. Yaş adımındaki vaadi düzelt** — [age_step.dart:29](../client-flutter/lib/screens/onboarding/age_step.dart#L29)
  "Sana uygun rakiplerle eşleştirmek için kullanırız" yazıyor ama yaş hiçbir yerde kullanılmıyor. Ya metni nötrle ("Profilin için") ya da özelliği gerçekten planla; 13 yaş altı politikasını (KVKK/COPPA) netleştir.

- [x] **13. Bot kimliklerini tek kaynağa topla** — [lobby_screen.dart:13](../client-flutter/lib/screens/lobby_screen.dart#L13) + [game_screen.dart:22-26](../client-flutter/lib/screens/game_screen.dart#L22-L26)
  Lobi `['Zeynep','Mehmet','Ayşe']`, oyun ekranı ayrı bir eşleme kullanıyor; sıra ve avatar stili tutmuyor. `lib/game/bots.dart` gibi tek bir tanım (id, isim, masa konumu) yap, iki ekran da oradan okusun.

- [x] **14. "Nasıl Oynanır" ekle + ilk yanlış basışı affet**
  Kurallar hiçbir yerde anlatılmıyor; yeni oyuncu -25 cezayı deneyerek öğreniyor. İlk oyun öncesi 3 kartlık kısa bir anlatım overlay'i + maç başına ilk `false_start`'ı cezasız uyarıya çevir ([game_controller.dart:101-105](../client-flutter/lib/game/game_controller.dart#L101-L105)).

- [x] **15. Splash'ı dokunuşla geçilebilir yap** — [splash_screen.dart:34-38](../client-flutter/lib/screens/splash_screen.dart#L34-L38)
  Her açılışta ~2.1 sn zorunlu bekleme var; `GestureDetector` ile tıklamada `_goNext()` çağır.

- [x] **16. Hedef puanı oyun içinde göster** — [game_screen.dart:447](../client-flutter/lib/screens/game_screen.dart#L447)
  "300'e ilk ulaşan kazanır" bilgisi hiçbir ekranda yok; orta alandaki etikete veya puan satırına "Puanın: 75 / 300" formatı ekle.

- [x] **17. Herkes bastıysa slam penceresini erken kapat** — [game_controller.dart:116-121](../client-flutter/lib/game/game_controller.dart#L116-L121)
  4 kayıt tamamlandıysa 4 saniyenin dolmasını beklemeden `_finishSlamWindow()` çağır — tempo iyileşir.

---

## 🟡 3. Kod kalitesinde değiştirilmesi gerekenler

- [ ] **18. String fazları enum'a çevir** — [game_controller.dart:21](../client-flutter/lib/game/game_controller.dart#L21)
  `enum GamePhase { waiting, swapping, slamWindow, scoring }` ve `submitHumanSlam` dönüşü için `enum SlamOutcome { recorded, already, tooEarly, falseStart, ignored }`. TS tarafında karşılığı zaten var ([types.ts:20-25](../server/game/types.ts#L20-L25)).

- [ ] **19. Üç kopya geri butonunu ortak widget'a çıkar** — [join_screen.dart:116](../client-flutter/lib/screens/join_screen.dart#L116), [lobby_screen.dart:129](../client-flutter/lib/screens/lobby_screen.dart#L129), [onboarding_screen.dart:190](../client-flutter/lib/screens/onboarding/onboarding_screen.dart#L190) → `widgets/circle_back_button.dart`.

- [ ] **20. Rank rozet renklerini tek yerde tanımla** — [round_result_screen.dart:23](../client-flutter/lib/screens/round_result_screen.dart#L23), [slam_celebration_screen.dart:18](../client-flutter/lib/screens/slam_celebration_screen.dart#L18), [game_over_overlay.dart:35](../client-flutter/lib/widgets/game_over_overlay.dart#L35) → `Palette.rankColors` listesi.

- [ ] **21. Üç benzer sıralama satırını tek `RankRow` widget'ında birleştir** — aynı üç dosyadaki `_row` / `_RankCard` / `_rankRow`.

- [ ] **22. `MapEntry<String,int>` yerine `RankEntry(label, points)` sınıfı kullan** — üç ekran arasında dolaşan anlamsız tip okunabilirliği düşürüyor.

- [ ] **23. İkiz satın alma fonksiyonlarını birleştir + yorumları düzelt** — [player_session.dart:84-114](../client-flutter/lib/session/player_session.dart#L84-L114)
  `purchaseCardSkin`/`purchaseFrame` neredeyse aynı; tek `_purchase` yardımcı fonksiyonuna indir. Ayrıca doc yorumu "zaten sahipse **false** döner" diyor, kod **true** dönüyor (satır 83 ve 103) — yorumu koda uydur.

- [ ] **24. GameController'da tek bildirim mekanizması seç** — [game_controller.dart:26-36](../client-flutter/lib/game/game_controller.dart#L26-L36)
  Hem 6 callback alanı hem `notifyListeners()` var; ikisinden birini bırak (callback'ler fiilen kullanılan — `ChangeNotifier`'ı kaldırmak en az işlik).

- [ ] **25. `PlayerSession`'ı static global'den injectable instance'a çevir** — test edilebilirlik için (widget testinde `PlayerSession.hasOnboarded = true` elle set ediliyor, bunun belirtisi).

- [ ] **26. Görünmez karakteri temizle** — [game_controller.dart:34](../client-flutter/lib/game/game_controller.dart#L34) yorumundaki `geçmiyor` kelimesinde zero-width space var; dosya içi aramayı bozar.

- [ ] **27. Geri sayım rebuild'ini izole et** — [game_screen.dart:90-97](../client-flutter/lib/screens/game_screen.dart#L90-L97)
  Her 100 ms `setState` tüm oyun ekranını (kartlar, yelpazeler, avatarlar) yeniden çiziyor. `ValueNotifier<double>` + yalnız `CountdownRing` ve süre etiketini saran `ValueListenableBuilder` kullan.

- [ ] **28. Boş fazlarda ticker'ı durdur** — [game_controller.dart:52](../client-flutter/lib/game/game_controller.dart#L52)
  `Timer.periodic`, `waiting/scoring` fazlarında boşa çalışıyor; faza göre başlat/durdur (küçük kazanç, düşük öncelik).

- [ ] **29. Pass-relay zincirine iptal mekanizması ekle** — [game_screen.dart:120-156](../client-flutter/lib/screens/game_screen.dart#L120-L156)
  `Future.delayed` zinciri iptal edilemiyor; tick süresi kısalırsa animasyonlar üst üste biner. Bir `_relayGeneration` sayacı tut, her `await` sonrası eşleşmiyorsa çık.

- [ ] **30. Küçük ekranlar için el dizilimini ölçekle** — [game_screen.dart:337-349](../client-flutter/lib/screens/game_screen.dart#L337-L349)
  4×70px kart + boşluklar ≈ 343px; 320-360dp cihazlarda taşar. `LayoutBuilder` ile kart genişliğini orana bağla.

---

## 🟠 4. Sunucu tarafında yapılması gerekenler

- [ ] **31. package.json'ı düzelt** — [server/package.json](../server/package.json)
  Var olmayan dosyayı gösteren `"main": "index.js"` satırını sil; `"engines": {"node": ">=22"}` ekle; boş `description/author`'ı doldur.

- [ ] **32. ESLint + Prettier ekle** — sunucuda hiç linter yok; `typescript-eslint` önerilen preset yeterli.

- [ ] **33. (Aşama 3 tasarım kuralı) Geçersiz intent tick'i çökertmesin**
  [swap.ts:52-56](../server/game/swap.ts#L52-L56) geçersiz kartta throw ediyor — saf fonksiyon için doğru. Colyseus room katmanında bunu yakala: geçersiz `cardId` gelen oyuncuya timeout kuralı uygula (`null` → rastgele kart) + logla. Motoru değiştirme, sözleşmeyi room'a koy.

- [ ] **34. (Üretim öncesi) Seed'li RNG'ye geç** — [deck.ts:55](../server/game/deck.ts#L55)
  Maç başına kaydedilen seed ile deterministik PRNG (örn. mulberry32); "deste hileliydi" şikayetinde maç aynen tekrar oynatılabilir.

- [ ] **35. Yanlış-slam kuralını sunucu spec'i olarak yaz**
  `FALSE_SLAM_PENALTY` TS'te tanımlı ama kullanılmıyor ([scoring.ts:5](../server/game/scoring.ts#L5)); kuralın gerçek tanımı yalnız Dart'ta yaşıyor. Aşama 3'ten önce davranışı (swapping'de basış = -25; pencerede 4'lüsüz ilk basış = no-op) sunucu tarafında test edilmiş fonksiyon olarak kodla.

---

## 🟡 5. Test tarafında yapılması gerekenler

- [ ] **36. Dart `Rules` için parity testleri yaz** *(en kritik test işi)* — `test/rules_test.dart`
  [server/game/__tests__/](../server/game/__tests__/) altındaki 24 senaryonun birebir Dart portu. İki motor sessizce ayrışmasın; Aşama 3 geçişinin güvencesi bu.

- [ ] **37. GameController unit testleri yaz** — exploit guard'ları regresyon testi olmalı:
  "4'lüsüz oyuncu pencerede ilk basış olamaz (`too_early`)", "swapping'de basış -25", "aynı pencerede ikinci basış `already`", bot slam sıralaması, 300 puanda winner. `fake_async` ile zamanı ilerlet.

- [ ] **38. Slam hint görünmezliği için widget regresyon testi** — [game_screen.dart:288](../client-flutter/lib/screens/game_screen.dart#L288)
  "İnsanın 4'lüsü yokken `4'lün tamam — HIMBIL'e bas!` metni asla render edilmez" testi.

- [ ] **39. PlayerSession testleri** — satın alma / bakiye düşme / persist + geri yükleme.

- [ ] **40. Sunucuya eksik senaryolar** — 4 oyuncu + `direction: -1`, aynı tick'te iki oyuncunun 4'lü tamamlaması, kart korunumu invariant'ı (property-based, `fast-check`).

---

## 🧹 6. Repo hijyeni (temizlik / silinecekler)

- [ ] **41. Kök `README.md` yaz** — proje tanıtımı + iki codebase'in kurulum/test komutları.
- [ ] **42. `CLAUDE.md`'yi commit et** — hâlâ untracked (`??`).
- [ ] **43. [client-flutter/README.md](../client-flutter/README.md) şablonunu gerçek içerikle değiştir.**
- [ ] **44. [.gitignore](../.gitignore) başındaki ölü `client-godot` bloğunu sil** (klasör kaldırılmıştı).
- [ ] **45. [.claude/settings.json](../.claude/settings.json)'daki bayat izinleri temizle** — eski `C:\game\hımbıl` yolu + `client-godot` `additionalDirectories` girdisi.
- [ ] **46. [pubspec.yaml](../client-flutter/pubspec.yaml) ve [analysis_options.yaml](../client-flutter/analysis_options.yaml) şablon yorumlarını sil** (~60 satır gürültü).
- [ ] **47. Sürümü dürüstleştir** — `1.0.0+1` → `0.2.0+1` (pre-release olduğu belli olsun).

---

## 🚀 7. Eklenmesi gerekenler (altyapı ve ürün — öncelik sırasıyla)

- [ ] **48. GitHub Actions CI kur** — iki job: `server` (npm ci → test → build) ve `client` (pub get → analyze → test). ~Yarım saatlik iş, kaliteyi kilitler.

- [ ] **49. Aşama 3: Colyseus entegrasyonu** *(ana iş)* — `server/rooms/` + `server/schema/` doldur, kural motorunu Room'a sar; client'a `lib/net/` WS katmanı ekle, `GameController`'ın yerel üretimini sunucu state dinlemeye çevir. Beraberinde: manifest'e INTERNET izni, `--dart-define` ile dev/prod sunucu adresi. Sunucu tasarım notu: geri sayımı "kalan süre" değil **deadline** olarak gönder (süre-sızıntısı sınıfı sorunlar tekrarlanmasın).

- [ ] **50. Oda kodu güvenliği (Aşama 4)** — 5 rakam ([lobby_screen.dart:48](../client-flutter/lib/screens/lobby_screen.dart#L48)) → 6 haneli alfanümerik + sunucuda katılım denemesi rate limit.

- [ ] **51. Crashlytics/Sentry ekle** — store'a çıkmadan önce crash görünürlüğü şart.

- [ ] **52. Temel analytics** — tur süresi, false-slam oranı, D1/D7 retention; balans kararları veriyle alınsın.

- [ ] **53. Ayarlar ekranı** — ses/titreşim/dil anahtarları + gizlilik politikası linki (store zorunluluğu).

- [ ] **54. Profil düzenleme** — onboarding sonrası isim/yaş/karakter/renk şu an **hiç** değiştirilemiyor (yalnız çerçeve Mağaza'dan değişiyor).

- [ ] **55. Ses efektleri + haptik** — özellikle slam anına `HapticFeedback.heavyImpact()` + ses; oyunun "juice"u burada.

- [ ] **56. i18n altyapısı** — tüm metinler TR hardcoded; `flutter_localizations` + ARB'yi metinler çoğalmadan kur.

- [ ] **57. Erişilebilirlik** — `GestureDetector` butonlarına `Semantics(button: true)`, 36px geri okları → 48px dokunma hedefi, `fontScale` büyükte taşma kontrolü.

- [ ] **58. Oda daveti paylaşımı** — `share_plus` + deep link (`himbil://join/34521`); Kodla Katıl akışının gerçek değeri bu.

- [ ] **59. Reconnect/disconnect dayanıklılığı (Aşama 6)** — grace timer + bot devralma + "bağlantı koptu" UI'ı.

- [ ] **60. Misafir hesap + sunucu envanteri (Aşama 7)** — jeton/envanter `shared_preferences`'tan sunucuya; jeton bakiyesini kolon değil **transaction ledger** olarak tut. IAP'ı bu taşınmadan önce **ekleme** (rootlu cihazda jeton düzenlenebilir).

- [ ] **61. Düşük öncelikliler** — dark mode, golden testler, 3/5/6 oyunculu masalar (sunucu motoru hazır, client `numPlayers = 4`'e sabit), turnuva/sezon ligi, izleyici modu, admin panel.

---

## Önerilen çalışma sırası

1. **1–8** (bir günlük iş; uygulama "gerçek cihazda utandırmaz" hale gelir)
2. **36–37** (güvenlik ağı: parity + controller testleri)
3. **48** (CI ile kaliteyi kilitle)
4. **9–17** (ürün düzeltmeleri)
5. **49** (Colyseus — büyük hamle; kılavuz §10'daki adımlar)
