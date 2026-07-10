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

- [x] **18. String fazları enum'a çevir** — [game_controller.dart:21](../client-flutter/lib/game/game_controller.dart#L21)
  `enum GamePhase { waiting, swapping, slamWindow, scoring }` ve `submitHumanSlam` dönüşü için `enum SlamOutcome { recorded, already, tooEarly, falseStart, ignored }`. TS tarafında karşılığı zaten var ([types.ts:20-25](../server/game/types.ts#L20-L25)).

- [x] **19. Üç kopya geri butonunu ortak widget'a çıkar** — [join_screen.dart:116](../client-flutter/lib/screens/join_screen.dart#L116), [lobby_screen.dart:129](../client-flutter/lib/screens/lobby_screen.dart#L129), [onboarding_screen.dart:190](../client-flutter/lib/screens/onboarding/onboarding_screen.dart#L190) → `widgets/circle_back_button.dart`.

- [x] **20. Rank rozet renklerini tek yerde tanımla** — [round_result_screen.dart:23](../client-flutter/lib/screens/round_result_screen.dart#L23), [slam_celebration_screen.dart:18](../client-flutter/lib/screens/slam_celebration_screen.dart#L18), [game_over_overlay.dart:35](../client-flutter/lib/widgets/game_over_overlay.dart#L35) → `Palette.rankColors` listesi.

- [x] **21. Üç benzer sıralama satırını tek `RankRow` widget'ında birleştir** — aynı üç dosyadaki `_row` / `_RankCard` / `_rankRow`.

- [x] **22. `MapEntry<String,int>` yerine `RankEntry(label, points)` sınıfı kullan** — üç ekran arasında dolaşan anlamsız tip okunabilirliği düşürüyor.

- [x] **23. İkiz satın alma fonksiyonlarını birleştir + yorumları düzelt** — [player_session.dart:84-114](../client-flutter/lib/session/player_session.dart#L84-L114)
  `purchaseCardSkin`/`purchaseFrame` neredeyse aynı; tek `_purchase` yardımcı fonksiyonuna indir. Ayrıca doc yorumu "zaten sahipse **false** döner" diyor, kod **true** dönüyor (satır 83 ve 103) — yorumu koda uydur.

- [x] **24. GameController'da tek bildirim mekanizması seç** — [game_controller.dart:26-36](../client-flutter/lib/game/game_controller.dart#L26-L36)
  Hem 6 callback alanı hem `notifyListeners()` var; ikisinden birini bırak (callback'ler fiilen kullanılan — `ChangeNotifier`'ı kaldırmak en az işlik).

- [x] **25. `PlayerSession`'ı static global'den injectable instance'a çevir** — test edilebilirlik için (widget testinde `PlayerSession.hasOnboarded = true` elle set ediliyor, bunun belirtisi).
  Not: Tam constructor-DI (her widget'a parametre olarak geçirme) 10 dosya/53 kullanım yeri boyunca aşırı invaziv olurdu; bunun yerine `PlayerSession.instance` swappable singleton deseni uygulandı — testler kendi `PlayerSession()` instance'ını oluşturup atayabiliyor, paylaşılan static alanları elle mutasyona uğratmıyor.

- [x] **26. Görünmez karakteri temizle** — [game_controller.dart:34](../client-flutter/lib/game/game_controller.dart#L34) yorumundaki `geçmiyor` kelimesinde zero-width space var; dosya içi aramayı bozar.

- [x] **27. Geri sayım rebuild'ini izole et** — [game_screen.dart:90-97](../client-flutter/lib/screens/game_screen.dart#L90-L97)
  Her 100 ms `setState` tüm oyun ekranını (kartlar, yelpazeler, avatarlar) yeniden çiziyor. `ValueNotifier<double>` + yalnız `CountdownRing` ve süre etiketini saran `ValueListenableBuilder` kullan.

- [x] **28. Boş fazlarda ticker'ı durdur** — [game_controller.dart:52](../client-flutter/lib/game/game_controller.dart#L52)
  `Timer.periodic`, `waiting/scoring` fazlarında boşa çalışıyor; faza göre başlat/durdur (küçük kazanç, düşük öncelik).

- [x] **29. Pass-relay zincirine iptal mekanizması ekle** — [game_screen.dart:120-156](../client-flutter/lib/screens/game_screen.dart#L120-L156)
  `Future.delayed` zinciri iptal edilemiyor; tick süresi kısalırsa animasyonlar üst üste biner. Bir `_relayGeneration` sayacı tut, her `await` sonrası eşleşmiyorsa çık.

- [x] **30. Küçük ekranlar için el dizilimini ölçekle** — [game_screen.dart:337-349](../client-flutter/lib/screens/game_screen.dart#L337-L349)
  4×70px kart + boşluklar ≈ 343px; 320-360dp cihazlarda taşar. `LayoutBuilder` ile kart genişliğini orana bağla.

---

## 🟠 4. Sunucu tarafında yapılması gerekenler

- [x] **31. package.json'ı düzelt** — [server/package.json](../server/package.json)
  Var olmayan dosyayı gösteren `"main": "index.js"` satırını sil; `"engines": {"node": ">=22"}` ekle; boş `description/author`'ı doldur.

- [x] **32. ESLint + Prettier ekle** — sunucuda hiç linter yok; `typescript-eslint` önerilen preset yeterli.
  `eslint.config.js` (flat config, `typescript-eslint` recommended + `eslint-config-prettier`) ve `.prettierrc.json` eklendi; `npm run lint` / `npm run format` script'leri. Bu arada ortaya çıkan mevcut bir `no-unused-vars` hatası (`deck.test.ts`'te ölü bir yerel değişken) da temizlendi.

- [x] **33. (Aşama 3 tasarım kuralı) Geçersiz intent tick'i çökertmesin**
  [swap.ts:52-56](../server/game/swap.ts#L52-L56) geçersiz kartta throw ediyor — saf fonksiyon için doğru. Colyseus room katmanında bunu yakala: geçersiz `cardId` gelen oyuncuya timeout kuralı uygula (`null` → rastgele kart) + logla. Motoru değiştirme, sözleşmeyi room'a koy.
  `server/rooms/` henüz boş olduğu için (Aşama 3 başlamadı) kod olarak uygulanacak bir room yok; sözleşme `resolveSwapTick`'in doc yorumuna ve kılavuzun §4'üne ("Geçersiz intent sözleşmesi") yazıldı — Room inşa edilirken doğrudan referans alınabilir.

- [x] **34. (Üretim öncesi) Seed'li RNG'ye geç** — [deck.ts:55](../server/game/deck.ts#L55)
  Maç başına kaydedilen seed ile deterministik PRNG (örn. mulberry32); "deste hileliydi" şikayetinde maç aynen tekrar oynatılabilir.
  `mulberry32(seed)` eklendi ve test edildi (`shuffle(deck, mulberry32(seed))` aynı seed'den birebir aynı sonucu üretiyor). Seed'i maç başına üretip kaydetmek room katmanının işi (Aşama 3); burada eklenen sadece deterministik PRNG'nin kendisi.

- [x] **35. Yanlış-slam kuralını sunucu spec'i olarak yaz**
  `FALSE_SLAM_PENALTY` TS'te tanımlı ama kullanılmıyor ([scoring.ts:5](../server/game/scoring.ts#L5)); kuralın gerçek tanımı yalnız Dart'ta yaşıyor. Aşama 3'ten önce davranışı (swapping'de basış = -25; pencerede 4'lüsüz ilk basış = no-op) sunucu tarafında test edilmiş fonksiyon olarak kodla.
  `submitSlamPress(playerId, state)` eklendi ([scoring.ts](../server/game/scoring.ts)) — saf fonksiyon, `recorded`/`already`/`tooEarly`/`falseStart`/`ignored` çıktılarını Dart'taki `submitHumanSlam` ile aynı kurallara göre üretir (forgiveness UX'i hariç, o client-local bir onboarding detayı). 6 yeni test.

---

## 🟡 5. Test tarafında yapılması gerekenler

- [x] **36. Dart `Rules` için parity testleri yaz** *(en kritik test işi)* — `test/rules_test.dart`
  [server/game/__tests__/](../server/game/__tests__/) altındaki 24 senaryonun birebir Dart portu (deal 4 + swap 5 + quartet 3 + deck'in pickObjectTypes/createDeck/shuffle kısmı 9 + scoring'in scoreSlamOrder kısmı 3). `mulberry32` (deck.ts) ve `submitSlamPress` (scoring.ts) bu 24'e dahil değil — ikisi de TS tarafına Dart portundan SONRA (madde 34/35) eklendi ve Dart karşılıkları yok: mulberry32 yalnız sunucu/oda katmanı için, submitSlamPress'in davranışı Dart'ta ayrı bir stateful `GameController.submitHumanSlam` olarak yaşıyor (bkz. madde 37). `Rules.objectPool`'un 4 türle sabitlenmiş olması nedeniyle (bkz. CLAUDE.md'deki bilinen ayrışma notu) "numPlayers != 4'te stock'ta kart kalır" senaryosu özel bir pool override'ıyla test edildi.

- [x] **37. GameController unit testleri yaz** — `test/game_controller_test.dart`
  Exploit guard'ları regresyon testi: "4'lüsüz oyuncu pencerede ilk basış olamaz (`tooEarly`)", "swapping'de basış -25 (ilk yanlış affedilir)", "aynı pencerede ikinci basış `already`", "gerçek 4'lüsü olan bot ilk basan olur ve 100 puan alır", "300 puana zaten ulaşmış oyuncu tur bittiğinde kazanan ilan edilir". Son iki test `fake_async` ile zamanı ilerletiyor; `hands`/`phase` public alanları üzerinden deterministik bir el düzeni kurup (insan → bot_east'e belirli bir kartı geçer) rastgele bot gecikmelerine rağmen tekrarlanabilir sonuç garantileniyor.

- [x] **38. Slam hint görünmezliği için widget regresyon testi** — `test/game_screen_slam_hint_test.dart`
  Gerçek `GameScreen`'i pompalayıp (fake-async tabanlı `tester.pump`) her karede: `4'lün tamam — HIMBIL'e bas!` metni görünüyorsa, ağaçtaki 4 `HimbilCard`'ın (insanın eli — botlar başka widget kullanıyor) gerçekten aynı `objectType`'ta olduğunu doğruluyor. Private `_controller`/`_humanHand` state'ine erişmeden, tamamen public widget ağacı üzerinden kara kutu regresyon testi.

- [x] **39. PlayerSession testleri** — `test/player_session_test.dart`
  Kart derisi/çerçeve satın alma (yeterli/yetersiz jeton, zaten sahip olma), `selectCardSkin`/`selectFrame`'in sahiplenilmemiş id'lerde no-op olması, `addTokens`, `recordMatchResult` (galibiyet/mağlubiyet serisi), ve `load()`'un önceki bir `PlayerSession`'ın `SharedPreferences`'a yazdığı bakiye/envanter/istatistikleri birebir geri yüklediğini doğrulayan testler.

- [x] **40. Sunucuya eksik senaryolar** — `server/game/__tests__/scenarios.test.ts`
  4 oyuncu + `direction: -1` (yön işaretinin komşuyu gerçekten değiştirdiğini 2 oyunculu testin aksine gösteren tam halka rotasyonu), aynı `resolveSwapTick` çağrısında iki farklı oyuncunun aynı anda 4'lü tamamlaması (`swap.ts` + `quartet.ts` entegrasyonu), ve `fast-check` ile property-based kart korunumu invariant'ı (rastgele el boyutları + yön için, çıktıdaki kart multiset'i girdiyle birebir aynı kalır). `fast-check` yeni bir devDependency olarak eklendi.

---

## 🧹 6. Repo hijyeni (temizlik / silinecekler)

- [x] **41. Kök `README.md` yaz** — proje tanıtımı + iki codebase'in kurulum/test komutları.
- [x] **42. `CLAUDE.md`'yi commit et** — hâlâ untracked (`??`).
  Zaten `39831cb` (#36-40) öncesindeki bir oturumda commit edilmiş; `git ls-files CLAUDE.md` tracked gösteriyor, ek işlem gerekmedi.
- [x] **43. [client-flutter/README.md](../client-flutter/README.md) şablonunu gerçek içerikle değiştir.**
- [x] **44. [.gitignore](../.gitignore) başındaki ölü `client-godot` bloğunu sil** (klasör kaldırılmıştı).
- [x] **45. [.claude/settings.json](../.claude/settings.json)'daki bayat izinleri temizle** — eski `C:\game\hımbıl` yolu + `client-godot` `additionalDirectories` girdisi.
- [x] **46. [pubspec.yaml](../client-flutter/pubspec.yaml) ve [analysis_options.yaml](../client-flutter/analysis_options.yaml) şablon yorumlarını sil** (~60 satır gürültü).
- [x] **47. Sürümü dürüstleştir** — `1.0.0+1` → `0.2.0+1` (pre-release olduğu belli olsun).

- [x] **62. Dokümanları Aşama 3 sonrası gerçekliğe güncelle** *(8 Temmuz kontrolünde eklendi, aynı gün yapıldı)* — üç dosya kodun gerisinde kalmıştı:
  - [CLAUDE.md](../CLAUDE.md) satır 11: "Stage 3+, not started: `server/rooms/` and `server/schema/` are empty" diyor — artık `HimbilRoom.ts`, `gameSession.ts`, `schema/messages.ts`, `index.ts` ve `persistence/` dolu. "Rule engine iki kez port edildi / client kopyası silinecek" bölümü de ağ katmanı (`lib/net/`) eklendiği için gözden geçirilmeli.
  - [README.md](../README.md): "`server/rooms/` ve `server/schema/` henüz boş (Aşama 3 başlamadı)" ifadesi güncellenmeli.
  - [docs/himbil-proje-kilavuzu.md](himbil-proje-kilavuzu.md) §7: 3. aşama "Henüz başlamadı — Colyseus henüz bağımlılık olarak eklenmedi" diyor; Colyseus artık dependency ve oda/oturum/reconnect/misafir-hesap katmanları mevcut. Aşama 3-4-6-7 durum işaretleri (⏳/✅) fiilî ilerlemeye göre düzeltilmeli, §10 "sıradaki adım" bölümü yenilenmeli.

---

## 🚀 7. Eklenmesi gerekenler (altyapı ve ürün — öncelik sırasıyla)

- [x] **48. GitHub Actions CI kur** — [.github/workflows/ci.yml](../.github/workflows/ci.yml): `server` (npm ci → test → build) ve `client` (pub get → analyze → test) job'ları, yerelde doğrulandı.

- [x] **49. Aşama 3: Colyseus entegrasyonu** *(ana iş)* — `server/rooms/HimbilRoom.ts` + `server/schema/messages.ts` yazıldı, kural motoru (`server/game/`) `HimbilGameSession` ile Room'a sarıldı. **Sapma:** Dart/Flutter için resmi bir Colyseus client SDK'sı olmadığından, `client-flutter/lib/net/` altında Colyseus'un ikili wire protokolünün (msgpack + JOIN_ROOM/ROOM_DATA çerçeveleri) elle, byte-seviyesinde doğru bir Dart implementasyonu yazıldı (`msgpack.dart`, `colyseus_protocol.dart`, `himbil_net_client.dart`) — `@colyseus/schema` state-sync yerine düz JSON mesajlar kullanılıyor, bkz. dosya içi doc yorumları. Gerçek sunucuya karşı 4 sahte istemciyle uçtan uca doğrulandı (oda kur → kodla katıl → oyun başlat → takas tick'i → hiçbir elin sızmaması). Manifest'e INTERNET izni eklendi; `--dart-define=HIMBIL_SERVER_HOST/PORT/TLS` ile dev/prod adresi (`net/net_config.dart`). Slam penceresi deadline (kalan süre değil, epoch ms) olarak gönderiliyor. **Bilinçli olarak yapılmadı:** `GameController`'ın yerel/bot-driven state üretimini sunucu state'ine bağlamak — mevcut çalışan bot-only deneyimi iki gerçek cihazda test etmeden bozma riskine karşı, bu adım ayrı bir entegrasyon çalışmasına bırakıldı. *(10 Temmuz: yapıldı — ekranlar `GameDriver` soyutlamasıyla sunucuya bağlandı, yerel mod offline/fallback oldu; 4 istemcili e2e `tool/e2e_online_match.dart` ile doğrulandı.)*

- [x] **50. Oda kodu güvenliği (Aşama 4)** — sunucu: [roomCode.ts](../server/rooms/roomCode.ts) 6 haneli alfanümerik (karışabilecek 0/O/1/I hariç) + `JoinRateLimiter` (`HimbilRoom.onAuth`'ta IP başına pencereli limit). İstemci: `lib/net/room_code.dart` aynı alfabeyle yerel kod üretiyor, `join_screen.dart` artık 6 haneli alfanümerik girişi sistem klavyesiyle alıyor (5 haneli sayısal tuş takımı yerine).

- [x] **51. Sentry ekle** — `main.dart`, `--dart-define=SENTRY_DSN` ile (boşsa no-op). **Kalan iş (sen yapmalısın):** gerçek bir Sentry (ya da Firebase Crashlytics) projesi oluşturup DSN'i sağlamak — harici hesap gerektiriyor.

- [x] **52. Temel analytics** — `lib/analytics/analytics_service.dart`: `round_completed` (süre), `false_slam`/`slam_recorded` (oran hesaplanabilir), `match_ended`; D1/D7 retention yerel `active days` kümesinden hesaplanıyor. Şimdilik yerel log (gerçek backend yok) — `AnalyticsSink` arayüzü sayesinde ileride tek satırla değiştirilebilir. *(10 Temmuz: backend eklendi — `POST /analytics/events` + SQLite `analytics_events`; client `HttpAnalyticsSink` batch'leyerek akıtıyor, offline'da sessizce kuyrukta tutuyor.)*

- [x] **53. Ayarlar ekranı** — [settings_screen.dart](../client-flutter/lib/screens/settings_screen.dart): ses/müzik anahtarları (`SoundService`'e kalıcı olarak bağlı) + dil satırı (bkz. #56) + [privacy_policy_screen.dart](../client-flutter/lib/screens/privacy_policy_screen.dart). Ana Menü'ye dişli ikonuyla bağlandı.

- [x] **54. Profil düzenleme** — [profile_edit_screen.dart](../client-flutter/lib/screens/profile_edit_screen.dart): onboarding'in `AgeStep`/`AvatarStep` widget'ları yeniden kullanıldı, isim için ayrı kompakt alan. Profil sekmesinden "Düzenle" ile açılıyor.

- [x] **55. Ses efektleri + haptik** — kullanıcı kendisi üstlendi (`lib/audio/`, `assets/sounds/`, `assets/music/`); dokunulmadı.

- [x] **56. i18n altyapısı** — `flutter_localizations` + ARB kuruldu (`l10n.yaml`, `lib/l10n/app_tr.arb`, `generate: true`). **Sapma:** altyapı gerçekten çalışıyor durumda ama yalnız bu oturumda yazılan iki ekranda (Ayarlar, Profil Düzenleme) kullanılıyor — geri kalan onlarca hardcoded TR metnini aynı yola taşımak ayrı, büyük bir mekanik iş (ayrıca çoğu ekran bu oturumda eşzamanlı düzenleniyordu, çakışma riskine girilmedi). *(10 Temmuz: tamamlandı — ~90 metin ARB'ye taşındı, tüm ekranlar `context.l10n` kullanıyor; yalnız bot adları ve mağaza katalog adları bilinçli olarak veri kaldı.)*

- [x] **57. Erişilebilirlik** — paylaşılan buton widget'larına (`CircleBackButton`, `SoftButton`, `GradientCta`, `HomeBottomNav`) `Semantics(button: true)`; `CircleBackButton` görsel daire 36px kalıp dokunma alanı 48px'e çıkarıldı; `MaterialApp.builder`'da `fontScale` [0.85, 1.3] aralığına kırpıldı (sabit piksel yerleşimli ekranlar tam erişilebilirlik aralığında kırılıyordu).

- [x] **58. Oda daveti paylaşımı** — `share_plus` + `himbil://join/<KOD>` deep link (Android intent-filter, iOS `CFBundleURLTypes`, `lib/net/deep_link_service.dart`). Lobi'deki oda koduna "Daveti Paylaş" butonu bağlandı.

- [x] **59. Reconnect/disconnect dayanıklılığı (Aşama 6)** — sunucu: `HimbilRoom.onDrop` + `allowReconnection` (30sn grace). İstemci: `HimbilNetClient` beklenmedik kopuşu (onaylı çıkıştan ayırt ederek) algılayıp otomatik yeniden bağlanmayı dener (~28sn, sunucunun grace süresiyle uyumlu); `ConnectionStatusBanner` widget'ı hazır. Gerçek sunucuya karşı bağlantıyı bilerek koparıp otomatik toparlanma uçtan uca doğrulandı. Ayrıca bu çalışma sırasında gerçek bir hata bulundu ve düzeltildi: `disconnect()` sunucuya "onaylı çıkış" kapanış kodunu (4000) hiç göndermiyordu, yani "< Menü" ile çıkmak bile sunucuda 30sn'lik grace hakkını israf ediyordu. **Bilinçli olarak yapılmadı:** bot devralma (disconnected oyuncunun yerini bir bot'un alması) — MVP davranışı, o oyuncunun takas seçimleri timeout kuralına (rastgele kart) düşüyor, turu durdurmuyor. *(10 Temmuz: yapıldı — grace dolunca koltuk `server/rooms/botPlayer.ts` botuna kalıcı devrediliyor: bot sezgisiyle kart verir, insansı gecikmeyle slam yarışına katılır.)*

- [x] **60. Misafir hesap + sunucu envanteri (Aşama 7)** — `server/persistence/` (SQLite, `better-sqlite3`): `guest_accounts` + **append-only `token_ledger`** (bakiye = `SUM(amount)`, hiçbir zaman mutable bir kolon değil) + `inventory_items`. `server/routes/guestRoutes.ts`: `POST /guest/register`, `POST /guest/me` — bilerek **jeton veren bir endpoint yok**, `awardTokens` yalnız güvenilir sunucu kodundan çağrılabilir. Gerçek sunucuya karşı doğrulandı (register/me + mevcut oda akışında regresyon yok). **Bilinçli olarak yapılmadı:** client'ın `PlayerSession`'ını bu API'ye taşımak — IAP'tan önce yapılması gereken, ayrı ve dikkatli bir geçiş (yapılması-gerekenler'in kendi notu), mevcut çalışan yerel akışı riske atmamak için bu oturumda başlatılmadı. *(10 Temmuz: ilk adım atıldı — client misafir hesabını kaydedip katılımda odaya iletiyor, maç sonu ödülleri sunucu defterine yazılıyor (denetim izi + gelecekteki mutabakatın kaynağı). Bakiyenin/envanterin tam taşınması hâlâ açık.)*

- [x] **61. Düşük öncelikliler (güvenli alt-küme)** — golden testler (`test/golden/`: Ayarlar + Gizlilik ekranları) ve admin panel (`@colyseus/monitor`, `server/routes/monitorRoutes.ts` — yalnız `HIMBIL_ADMIN_TOKEN` ortam değişkeni set edilmişse mount edilir, token'sız istekler 404). **Kapsam dışı bırakıldı:** dark mode, 3/5/6 oyunculu masalar, turnuva/sezon ligi, izleyici modu. *(10 Temmuz: dark mode yapıldı — `Palette` çift varyantlı hale getirildi (statik erişim korunarak), Ayarlar'a kalıcı "Koyu Tema" anahtarı eklendi; ayrıca sunucu defterinden türeyen hilelenemez `GET /leaderboard` + Profil sekmesi bağlantısı eklendi. Kalan: 3/5/6 oyunculu masalar, turnuva/sezon ligi, izleyici modu.)*

---

## Önerilen çalışma sırası

1. **1–8** (bir günlük iş; uygulama "gerçek cihazda utandırmaz" hale gelir)
2. **36–37** (güvenlik ağı: parity + controller testleri)
3. **48** (CI ile kaliteyi kilitle)
4. **9–17** (ürün düzeltmeleri)
5. **49** (Colyseus — büyük hamle; kılavuz §10'daki adımlar)
