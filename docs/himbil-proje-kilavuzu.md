# Hımbıl — Gerçek Zamanlı Mobil Oyun Proje Kılavuzu

Bu doküman, geleneksel Türk kağıt oyunu **Hımbıl**'ın (bazı yörelerde "Bom") gerçek zamanlı çok oyunculu mobil versiyonunu sıfırdan geliştirmek için hazırlanmış teknik yol haritasıdır. Teknoloji seçimleri, mimari, veri modeli, kritik tasarım kararları ve adım adım geliştirme planını içerir.

---

## 1. Oyunun Özeti ve Teknik Kalbi

**Oynanış:** Oyuncu sayısı kadar nesne (meyve, şehir vs.) belirlenir; her nesneden oyuncu sayısı kadar kart yazılır. Herkes 4 kart çeker. Amaç, aynı nesnenin yazılı olduğu 4 kartı elde toplamaktır. Her tur oyuncular işe yaramayan bir kartı komşusuna verir. 4'lüyü tamamlayan oyuncu elini ortaya vurup **"Hımbıl!"** der; diğerleri hemen ellerini üstüne koyar. Puanlama elin sırasına göre yapılır (ilk basan 100, sonrakiler 75, 50, 25...).

**Projenin iki teknik zorluğu:**
1. **Eşzamanlı kart geçişi** — herkesin aynı anda komşusuna kart vermesi.
2. **"Kim önce Hımbıl dedi" yarışı** — timing-kritik, reaksiyona dayalı bir slam mekaniği.

Mimarinin tamamı bu iki şeyi **hilesiz** ve **adil** çözmek üzerine kuruludur.

---

## 2. Teknoloji Yığını (Stack)

| Katman | Seçim | Neden |
|--------|-------|-------|
| **İstemci (mobil)** | **Flutter** (Dart) | *Karar değişti — bkz. not aşağıda.* UI-ağırlıklı bir kart oyunu için hızlı geliştirme, hot reload, tek kod tabanından iOS/Android/web/masaüstü export. |
| **Gerçek zamanlı taşıma** | **WebSocket (TCP)** | Slam çözümü sunucu zaman damgasına dayandığı için birkaç on ms gecikme sorun değil. WebRTC/UDP gereksiz karmaşıklık. |
| **Otoriter oyun sunucusu** | **Colyseus** (Node/TypeScript) | Oda bazlı otoriter state senkronizasyonunu hazır verir (schema delta sync). MVP'yi en hızlı buradan çıkarırsın. |
| **Veritabanı** | **PostgreSQL** | Hesap, istatistik, maç geçmişi, leaderboard. Canlı maç durumu için DEĞİL. |
| **Redis** | **Başlangıçta yok** | Sadece yatay ölçeklemede (node'lar arası pub/sub, matchmaking kuyruğu) devreye girer. Tek-node MVP'de gereksiz. |

**Başlangıç seti:** Flutter + WebSocket + Colyseus + PostgreSQL.

> **Not (istemci kararı revize edildi):** Kılavuz başlangıçta Godot'u önermişti; proje ilerledikten sonra **Flutter**'a geçildi (bkz. `client-flutter/`). Gerekçe: oyun düz `Material` widget'larıyla (özel `Tween`/`AnimationController` animasyonlarıyla) inşa edildi, bir oyun motorunun fizik/parçacık sistemine ihtiyaç duymadı; Flutter'ın hot reload'u UI-ağır bir kart oyununda iterasyonu hızlandırdı. `client-godot/` klasörü kaldırıldı.

**Alternatifler (sonradan değerlendirilebilir):**
- *Colyseus yerine* **Nakama** (Go): auth, matchmaking, leaderboard, storage hepsi built-in. "Gerçek ürün, uzun vadeli" hedefi için daha güçlü ama öğrenme eğrisi daha dik.
- *Colyseus yerine* **Elixir + Phoenix Channels**: mimari olarak ideal (her oda = bir process, BEAM tam bu iş için yapılmış), hata toleransı mükemmel. Dezavantajı yeni dil öğrenmek.
- *Flutter yerine* **Godot**: slam animasyonunun "juicy" hissi için bir oyun motoru gerekirse (parçacık efektleri, fizik tabanlı kart fırlatma) sonradan değerlendirilebilir.

---

## 3. Temel Mimari İlke: Otoriter Sunucu (Server-Authoritative)

**Tüm oyun durumu sadece sunucuda tutulur.** Client'lar yalnızca "niyet" (intent) gönderir, sonucu asla kendileri hesaplamaz.

İki sebebi var:
- **Hile önleme:** Kart bilgisi client'ta olursa rakip oyuncunun eli okunabilir. Her oyuncuya WebSocket üzerinden **sadece kendi eli** + herkese açık bilgi (puanlar, kart sayıları) push edilir.
- **Slam adaleti:** "Kim önce bastı" kararını sunucu, mesajın kendisine ulaşma sırasına göre verir. Client'ın söylediği zamana asla güvenilmez.

```
[Mobil Client] ──WebSocket──> [Gateway / Auth katmanı]
                                       │
                                       ▼
                           [Matchmaking (oda kodu)]
                                       │
                                       ▼
                        [Otoriter Oyun Sunucusu / Oda]
                          - tick loop, kurallar, state
                               │            │
                          [Redis]        [Postgres]
                        (ölçekleme)     (kalıcılık)
```

**Altın kural:** Client sadece **intent** yollar, **state** alır. Oyun mantığı client'ta hiç çalışmaz.

---

## 4. Kart Geçiş Modeli (En Önemli Tasarım Kararı)

Fiziksel oyundaki "herkes aynı anda sürekli kart fırlatıyor" hali netcode'a temiz oturmaz. İki model var; **Model A öneriliyor.**

### Model A — Senkronize Takas Tick'i (ÖNERİLEN)
- El boyutu her zaman **4'te sabit** kalır.
- Her tick'te her oyuncu vermek istediği 1 kartı seçer.
- Tick çözülünce **herkes aynı anda** komşusuna verir, diğer komşudan alır → yine 4 kart.
- **Tick ilerlemesi:** ya herkes kartını kilitleyince, ya da timeout'ta (örn. 3 sn) seçmeyenler için sunucu rastgele atar. Bu, oyunu akışta tutar ve "hızlı karar verme" gerilimini yaratır.
- **Avantaj:** "Hımbıl'dan önce kart vermek zorundasın" kuralı bu modelde **otomatik** sağlanır — takas zaten bir kart vermeyi içeriyor. (İlk-oyuncu istisnası fiziksel oyun artığı, dijitalde gerek yok.)

### Model B — Serbest Akış (async)
Herkes istediği an kart fırlatır. Kaosa daha sadık ama akış kontrolü (kuyruk birikmesi, el boyutu dalgalanması) ciddi karmaşıklık ekler. **Önerilmiyor.**

---

## 5. Slam Yarışı (Oyunun Ruhu)

Takas çözülünce sunucu her eli kontrol eder ve 4'lüyü tamamlayanı **"slam'a uygun"** olarak işaretler. Ama kazananı sunucu otomatik vermez:

- Oyuncu **HIMBIL butonuna basmalı.**
- Sunucu, basışları **geliş sırasına göre** puanlar (100, 75, 50, 25...).
- Böylece insan reaksiyon hızı önemini korur.
- **Yanlış slam cezası:** 4'lüsü yokken basan oyuncu ceza puanı alır (fiziksel oyundaki "ceza puanı" kuralı).

**Gecikme adaleti notu:** En basit yol "sunucuya ulaşma sırası" — yüksek ping'li oyuncu hafif dezavantajlı olur. İstersen sonradan client zaman damgası + sunucu doğrulama penceresiyle lag kompanzasyonu eklersin. MVP'de gerek yok.

---

## 6. Veri Modeli (Kavramsal)

Sunucuda tutulacak temel yapılar:

- **Card:** `{ id, objectType }` — örn. `{ id: 12, objectType: "muz" }`
- **Player:** `{ id, name, hand: Card[4], score, connected: bool }`
- **Room / GameState:**
  - `players: Player[]`
  - `phase: "waiting" | "swapping" | "slamWindow" | "scoring" | "finished"`
  - `tickNumber`
  - `slamOrder: playerId[]` (o turdaki basış sırası)
  - `roomCode`
  - `direction` (saat yönü / ters)

**Client'a push edilen (kısıtlı) view:** oyuncunun sadece kendi `hand`'i + diğerlerinin `handSize` ve `score` bilgisi. Rakip kartlarının içeriği ASLA gönderilmez.

---

## 7. Geliştirme Aşamaları (Sırayla)

> **En kritik tavsiye:** 1. ve 2. aşamayı atlamadan yap. Çoğu kişi direkt multiplayer'a dalıp hem oyun mantığını hem netcode'u aynı anda debug etmeye çalışırken boğulur. Mantığı ağdan ayırırsan ikisini ayrı ayrı çözersin.

1. ✅ **Ağsız kural motoru.** Deste üretimi, takas, 4'lü tespiti, puanlama — saf mantık, ağ yok. Birim testlerle. Tüm oyun riskini burada azaltırsın. *(`server/game/` — deck/deal/swap/quartet/scoring, hepsi test edilmiş.)*
2. ✅ **Tek kişilik + bot.** Kural motorunu basit AI'la sarıp tüm UI/UX'i buna karşı kur. Netcode yok, oynanabilir oyun hızlıca elde edilir. *(`client-flutter/lib/game/` — kendi rule engine + bot AI portu; UI Sıcak Karnaval tasarım referansına göre kuruldu: ana menü (Oyna/Profil sekmeleri, liderlik tablosu), oda kur/kodla katıl, lobi, oyun ekranı, slam kutlaması, tur sonucu, maç sonu.)*
   - *İlk açılış onboarding'i eklendi (tasarım referansında yoktu, sonradan tasarlandı):* `client-flutter/lib/screens/onboarding/` — Hoş Geldin → İsim → Yaş → Avatar Oluştur (karakter ikonu/renk/çerçeve seçimi) → Tamamlandı, parallax geçiş + staggered animasyonlarla. Profil `client-flutter/lib/session/player_session.dart` üzerinden `shared_preferences` ile cihazda kalıcı tutuluyor (`hasOnboarded` bayrağı sayesinde sadece ilk açılışta gösteriliyor); gerçek hesap sistemi hâlâ Aşama 7'de.
   - *Uygulama markalaması:* `design/logo-export/` altındaki resmî logo hem Android/iOS launcher icon'u (`flutter_launcher_icons` ile üretildi) hem uygulama içi logo rozetleri (Ana Menü başlığı, onboarding Hoş Geldin ekranı) olarak entegre edildi.
3. ⏳ **Otoriter sunucu + 1 gerçek client.** Kural motorunu sunucuya taşı; client intent yollar, sunucu state push eder. İki instance lokal test. *(Henüz başlamadı — `server/rooms/` ve `server/schema/` boş, Colyseus henüz bağımlılık olarak eklenmedi. Client şu an tamamen yerel/sahte state ile çalışıyor.)*
4. ⏳ **Odalar + matchmaking (oda kodu).** Çok oyuncu, kodla katılma. *(Client'ta UI akışı var — Lobi/Kod ile Katıl ekranları — ama gerçek ağ bağlantısı yok, botlarla simüle ediliyor.)*
5. ⏳ **Gerçek zamanlı takas loop'u + slam yarışı.** Tick, eşzamanlı takas, slam çözümü, yanlış-slam cezası. Tick zamanlamasını/hissini ayarla. *(Client-lokal olarak çalışıyor; sunucu otoritesi eklenince bu mantık `server/game/`'e taşınacak.)*
6. ⏳ **Dayanıklılık.** Yeniden bağlanma, kopma yönetimi (bot devralma ya da grace timer), gecikme toleransı.
7. ⏳ **Kalıcılık & meta.** Hesap, istatistik, leaderboard, kozmetikler. *(Profil sekmesindeki istatistik/liderlik tablosu şimdilik sahte veri.)*
8. ⏳ **Ölçekleme.** Redis pub/sub, çok-node, yük testi.

---

## 8. Nelere Dikkat Edilmeli (Kritik Noktalar)

- **Client'a asla güvenme.** Rakip kartları, puan hesabı, slam kazananı — hepsi sunucuda. Client sadece görüntüler.
- **Rakip eli sızıntısı.** State senkronizasyonu yaparken yanlışlıkla tüm oda state'ini herkese push etmek en yaygın hata. Her oyuncuya filtrelenmiş view gönder.
- **Slam anlaşmazlığı.** "Kim önce bastı" kararı tek otorite olan sunucuya ait. Client timestamp'ine güvenme.
- **Tick zamanlaması.** Kart geçiş hızı sabit timer mı, oyuncu kontrollü mü? Sabit timer daha adil ama gerilimi azaltır; test edip dengeyi bul.
- **Reconnect / disconnect.** Oyuncu kopunca ne olacak? Grace timer, bot devralma, ya da turu iptal — MVP'de basit bir grace timer yeterli.
- **Aşamaları karıştırma.** Kural motorunu netcode'dan ayrı tut; ikisini aynı anda debug etme.
- **Erken optimizasyon.** Redis, çok-node, matchmaking havuzu MVP'de yok. Önce tek sunucuda çalışan oyunu bitir.

---

## 9. Önerilen Klasör Yapısı (Başlangıç)

```
himbil/
├── client-flutter/        # Flutter projesi (UI, animasyon; WebSocket bağlantısı henüz yok)
│   ├── assets/
│   │   ├── icon/          # Launcher icon kaynağı (flutter_launcher_icons)
│   │   └── images/        # Uygulama içi logo vb. görseller
│   └── lib/
│       ├── game/          # Rule engine + bot AI'ın client-tarafı portu (Aşama 2)
│       ├── screens/       # Ana Menü, Kod ile Katıl, Lobi, Oyun, Slam, Tur Sonucu
│       │   └── onboarding/  # İlk açılış: Hoş Geldin, İsim, Yaş, Avatar Oluştur, Tamamlandı
│       ├── session/       # PlayerSession — isim/yaş/avatar, shared_preferences ile kalıcı
│       ├── widgets/       # Paylaşılan bileşenler (kart, buton, alt nav, UserAvatar, vb.)
│       └── theme/         # Sıcak Karnaval tasarım token'ları (palet, tipografi, avatar seçenekleri)
├── server/                # Colyseus sunucusu (TypeScript)
│   ├── rooms/             # Oyun odası mantığı (Aşama 3 — henüz boş)
│   ├── game/              # Ağdan bağımsız kural motoru (Aşama 1 — tamamlandı)
│   │   └── __tests__/     # Kural motoru birim testleri
│   └── schema/            # Senkronize state şemaları (Aşama 3 — henüz boş)
├── design/                # Tasarım handoff paketi (Sıcak Karnaval referansı) + logo-export/ (resmî logo kaynakları)
└── docs/                  # Bu kılavuz ve tasarım notları
```

**Not:** Kural motoru sunucuda (`server/game/`) ağdan tamamen bağımsız yazıldı ve test edildi (Aşama 1 tamam). Client tarafında da (`client-flutter/lib/game/`) aynı mantığın bağımsız bir portu var — bu, Aşama 2'nin (tek kişilik + bot) sunucu olmadan oynanabilir olmasını sağladı. Aşama 3'e geçildiğinde client'taki bu yerel mantık kaldırılıp sunucudan gelen state'e bağlanmalı; iki kopyanın kalıcı olarak birbirinden ayrı yaşaması hedeflenmiyor.

---

## 10. Sıradaki Somut Adım

Aşama 1 ve 2 tamamlandı: kural motoru sunucuda test edilmiş durumda, client'ta da tek-kişilik + bot ile oynanabilir bir prototip var (Sıcak Karnaval tasarımına göre kurulu UI dahil, artık ilk-açılış onboarding'i ve resmî uygulama logosu da entegre). Bunlar client-lokal UX/marka cilası — Aşama 3'ü bloklamıyor. **Sıradaki adım Aşama 3: otoriter sunucu + 1 gerçek client.** `server/`'a Colyseus'u bağımlılık olarak ekle, `server/game/`'deki kural motorunu bir Colyseus `Room`'a sar (`server/rooms/`), `server/schema/`'da senkronize state şemasını tanımla; sonra `client-flutter` tarafında bir WebSocket katmanı ekleyip `game_controller.dart`'ın yerel/sahte state üretimini sunucudan gelen state'i dinlemekle değiştir.
