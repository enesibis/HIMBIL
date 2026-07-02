# Handoff: Hımbıl — Mobil Uygulama Tasarımı (Yön 1a: "Sıcak Karnaval")

## Genel Bakış

Bu paket, `himbil-proje-kilavuzu.md` dosyasındaki teknik yol haritasına göre geliştirilecek **Hımbıl** gerçek zamanlı çok oyunculu kağıt oyununun mobil uygulaması için hazırlanmış **uçtan uca tasarım referansıdır**: ana menü → oda kur/kodla katıl → lobi → oyun (el, kart takası, HIMBIL slam yarışı) → tur sonucu → maç sonu, artı profil/liderlik sekmesi.

İki görsel yön tasarlandı ("Sıcak Karnaval" ve "Şeker Parti"); **bu handoff sadece seçilen yön olan 1a — Sıcak Karnaval'ı** kapsar (kırmızı/hardal, kağıt-oyunu hissi, Baloo 2 + Nunito tipografisi).

## Tasarım Dosyaları Hakkında — ÖNEMLİ

Bu pakette bulunan `.dc.html` dosyası **HTML/React ile yapılmış bir tasarım referansıdır** — davranışı ve görünümü göstermek için hazırlanmış tıklanabilir bir prototiptir, **doğrudan kopyalanacak üretim kodu değildir.**

Proje kılavuzuna göre gerçek istemci **Godot** (GDScript/C#) ile yazılacak. Godot; HTML, CSS veya React çalıştırmaz. Yapılacak iş: bu tasarımdaki ekranları, renkleri, tipografiyi, spacing'i ve etkileşim/animasyon davranışını **Godot'un Control node sistemine göre yeniden inşa etmektir** (aşağıdaki "Godot'a Çeviri Notları" bölümüne bakın), üretim kodunu HTML'den kopyalamak değil.

Ayrıca: **prototipteki tüm oyun mantığı (kart dağılımı, takas sırası, kimin önce Hımbıl dediği) sahnelenmiş/sabit kodlanmış demo verisidir** — sadece akışı göstermek içindir. Gerçek uygulamada kılavuzun 3. bölümündeki **"Otoriter Sunucu"** ilkesi geçerlidir: tüm oyun durumu Colyseus sunucusunda hesaplanır, client sadece intent (niyet) gönderir ve sunucudan gelen state'i gösterir. Bu prototipteki `setTimeout`/rastgele gecikmelerle simüle edilen "bot katılıyor", "4 saniye sayaç", "kim önce bastı" gibi davranışların hepsi gerçek uygulamada WebSocket üzerinden sunucudan gelen mesajlarla tetiklenmelidir.

## Fidelity

**Yüksek fidelity (hifi).** Renkler, tipografi, spacing, köşe yuvarlaklıkları, gölgeler ve metinler nihai durumdadır — geliştirici bunları piksel-precision hedefleyerek Godot'ta yeniden üretmelidir. Zamanlama değerleri (4 saniyelik takas süresi, 2 tur, puanlama 100/75/50/25) kılavuzdaki tasarım kararlarıyla uyumludur ve gerçek değerler olarak alınabilir; ama az önce belirtildiği gibi bunları **tetikleyen mekanizma** (sunucu vs. sahte timer) değişecektir.

## Dosyalar

- `Himbil Prototip (tasarım referansı).dc.html` — tıklanabilir tasarım referansı. İki yön yan yana durur (`#1a` ve `#1b` bölümleri); **sadece `#1a` bölümünü** (soldaki telefon) referans alın, `#1b` karşılaştırma için bırakıldı.
- `himbil-proje-kilavuzu.md` — orijinal teknik/mimari kılavuz (stack, veri modeli, geliştirme aşamaları).

Tarayıcıda açıp her ekranı deneyerek (kart seçme, HIMBIL'e basma, kod girme vb.) davranışı birebir gözlemleyebilirsiniz.

## Ekranlar

### 1. Ana Menü (Home)
**Amaç:** Oyuncu uygulamayı açtığında karşılaştığı ekran; hızlı oyna, özel oda kur/katıl, profil/liderlik.
**Layout:** Dikey flex, üstte 60px status-bar boşluğu. Header: sol logo rozeti (34×34, radius 11, kırmızı gradyan `#FF6F5A→#E14B3B`) + "Hımbıl" başlığı (Baloo 2, 800, 23px, `#2E1D12`); sağda 40×40 gradyan halkalı avatar (kullanıcı baş harfi).
**"Oyna" sekmesi:**
  - Karşılama metni: "Merhaba," (Nunito 700, 14px, `#8A7660`) + "Bugün Hımbıl var!" (Baloo 2 700, 23px, `#2E1D12`).
  - Ana CTA kartı: tam genişlik, radius 28, gradyan `#FF6F5A→#D6432F`, üstte %50 yükseklikte beyaz parlaklık overlay'i (`rgba(255,255,255,.32)→şeffaf`), içinde play-icon + "HIZLI OYNA" (Baloo 2 800, 24px, beyaz) ve alt satır "Rastgele oyuncularla eşleş" (Nunito 700, 13px, `rgba(255,255,255,.88)`). Gölge: `0 12px 0 #A82E20, 0 22px 30px rgba(225,75,59,.32)` (katı "basılı buton" gölgesi + yumuşak yayılma).
  - Ayraç: "VEYA ÖZEL ODA" ortada, iki yanda 2px çizgi.
  - İki eşit genişlikte ikincil kart buton: "Oda Kur" (turuncu/hardal ikon rozeti, plus ikonu) ve "Kodla Katıl" (mavi ikon rozeti, anahtar ikonu). Kart: beyaz (`#FFFDF8`), radius 22, ince kenarlık `rgba(46,29,18,.05)`.
**"Profil" sekmesi:** 2×2 istatistik kartı grid'i (Oyun/Galibiyet/Kazanma Oranı/En İyi Seri — her biri renkli ikon rozeti + büyük sayı + küçük etiket), altında liderlik tablosu listesi (rank, isim, puan).
**Alt gezinme:** Yüzen pill-bar (beyaz, radius 24, gölgeli), iki sekme "Oyna"/"Profil"; aktif sekme kırmızı gradyan arkaplan + beyaz metin/ikon alır.

### 2. Kod ile Katıl (Join)
**Amaç:** Arkadaşının oda koduyla mevcut bir odaya katılma.
**Layout:** Geri oku (36×36 yuvarlak, beyaz, gölgeli) → başlık "Kod ile Katıl" (Baloo 2 700, 21px) → alt metin → 5 adet kod kutusu (46×58, radius 14, alt kenarda 4px kırmızı vurgu çizgisi, girilen hane Baloo 2 800 22px) → "Örnek kod ile doldur (34521)" linki (test/demo kısayolu) → 3×4 sayısal tuş takımı (her tuş 52px yükseklik, radius 16, basılınca `scale(.93)`).
**Davranış:** 5. hane girilince ~500ms sonra otomatik lobiye geçer.

### 3. Lobi (Lobby)
**Amaç:** Oda dolana kadar bekleme ekranı.
**Layout:** Geri oku → "bilet" görünümlü oda kodu kartı (kesikli kenarlık, krem gradyan, 36px oda kodu, harf aralığı 6px) → 2×2 oyuncu slotu grid'i (her biri gradyan halkalı 56px avatar + isim + "✓ Hazır" ya da yanıp-sönen "Bekleniyor…" durumu) → alt kısımda "Oyunu Başlat" CTA (tüm slotlar dolana kadar %45 opaklık + tıklanamaz, dolunca tam renk).
**Davranış (prototipte simüle):** Lobiye girildikten ~1.4–1.6 sn sonra 3 bot aynı anda "Hazır" olur. **Gerçek uygulamada bu, sunucudan gelen "oyuncu katıldı" event'leriyle tetiklenmeli.**

### 4. Oyun Ekranı (Game)
**Amaç:** Elindeki 4 kartı yönetme, komşuna kart verme, HIMBIL'e basma.
**Layout:**
  - Üst şerit: 3 rakip, her biri gradyan halkalı 44px avatar + isim + "kart sayısı" rozeti (mini üst üste kart ikonu + "4").
  - Orta alan: yumuşak radial-gradient "masa" arka planı, üzerinde 60px dairesel sayaç (beyaz daire içinde SVG progress ring, kırmızı stroke, `stroke-dashoffset` her 100ms güncellenir — 4 saniyelik geri sayım), altında "Tur X/2 · Takas Y/3" etiketi.
  - İpucu satırı: takas sırasında "İşine yaramayan kartı seç, komşuna ver"; el tamamlanınca yeşil "4'lün tamam — HIMBIL'e bas!".
  - El: 4 kart yan yana (70×96, radius 16, 3px kırmızı kenarlık, krem gradyan iç, köşelerde küçük "pip" olarak aynı meyve ikonu %45 opaklıkla), seçili kart `translateY(-14px) scale(1.06)` ile yukarı kalkar.
  - HIMBIL butonu: 116×116 daire, kırmızı gradyan, üstte yarım-daire parlaklık overlay'i, el tamamlanınca `himPulseA` keyframe'i ile nabız gibi genişleyen gölge halkası.
  - Erken/yanlış basışta: kırmızı "Erken bastın! Ceza puanı" toast'ı, `himShake` animasyonuyla sarsılır.
**Davranış:** Her takas 4 saniye; süre dolunca ya da kart seçilince el güncellenir. **Prototipte el ilerlemesi önceden yazılmış (scripted) bir dizi — gerçek uygulamada sunucudan gelen `hand` state'i render edilecek.**

### 5. Slam Ekranı (HIMBIL anı)
**Amaç:** HIMBIL'e basıldıktan hemen sonraki kutlama + sıralama reveal'i.
**Layout:** Tam ekran turuncu→kırmızı gradyan, dönen "ışın" deseni (repeating-conic-gradient, 14s'de bir tam tur), ortada büyük "HIMBIL!" (Baloo 2 800, 42px, beyaz, `himPop` animasyonu), altında 4 oyuncunun sırayla (200ms arayla, `himRise` animasyonu) beliren kartları: altın/gümüş/bronz/nötr gradyanlı rozet (1-2-3-4), isim, "+puan".
**Davranış:** ~1.7 saniye sonra otomatik "Tur Sonucu" ekranına geçer.

### 6. Tur Sonucu (Round Result)
Slam ekranındaki sıralama kartlarının sade/statik hâli + "Sonraki Tur →" (ya da son turda "Final Sonuçlar →") CTA.

### 7. Maç Sonu (Match End)
Kazananın adı + büyük kupa rozeti (glow animasyonlu), arka planda birkaç renkli konfeti noktası, toplam puana göre sıralanmış final listesi, "Tekrar Oyna" / "Ana Menü" butonları.

## Etkileşim & Davranış Özeti

- Tüm tıklanabilir öğelerde `scale(.92–.98)` basma efekti (native buton "press" hissi).
- Sekme/ekran geçişleri anlık (fade/transition yok) — geçiş animasyonu eklemek istenirse Godot tarafında `AnimationPlayer` ile crossfade önerilir.
- Sayaç: her 100ms bir güncellenen sürekli değer (Godot: `Tween` veya `_process` içinde `TextureProgressBar.value`).
- Kart seçme → 350ms bekleme (uçuş animasyonu için) → yeni el.

## Tasarım Token'ları (Yön 1a — Sıcak Karnaval)

**Renkler**
- Zemin: `#FBF3E4` (krem) + üstüne 3 katmanlı radial-gradient vurgu: `rgba(240,169,59,.22)`, `rgba(225,75,59,.14)`, `rgba(63,143,107,.08)`
- Kart/panel zemini: `#FFFDF8`
- Metin (ana): `#2E1D12` · Metin (ikincil): `#8A7660`
- Ana aksan (kırmızı): `#E14B3B` / açık ton `#FF6F5A` / koyu ton (gölge) `#B93424` / `#A82E20` / `#D6432F`
- İkincil aksan (hardal/altın): `#F0A93B` / `#FFCB7A`
- Oyuncu rozet renkleri: kırmızı `#E14B3B`, hardal `#F0A93B`, yeşil `#3F8F6B`, lacivert `#3B6EA5`
- Rozet (sıralama) gradyanları: 1. `#FFE29A→#F0A93B` (altın), 2. `#EDEDED→#B9B9C2` (gümüş), 3. `#E3A97A→#B87333` (bronz), 4. `#D9D3C8→#AFA593` (nötr)

**Tipografi**
- Başlıklar / butonlar: **Baloo 2** (500/600/700/800) — Google Fonts, OFL lisanslı.
- Gövde metni: **Nunito** (400/600/700/800/900) — Google Fonts, OFL lisanslı.
- Minimum metin boyutu 11px (yalnızca ikincil etiketlerde); ana içerik 13–24px arası.

**Köşe Yuvarlaklığı:** küçük rozet/ikon 9–15px, kart/panel 16–22px, büyük CTA/panel 24–28px, avatar/daire tam yuvarlak.

**Gölgeler:** iki katmanlı — "katı" alt gölge (buton basılı hissi, örn. `0 10px 0 #A82E20`) + yumuşak yayılan gölge (`0 16-24px blur, düşük opaklık renkli`).

## Godot'a Çeviri Notları (geliştirici için)

- **Sahne yapısı:** Her ekran (`Home`, `Join`, `Lobby`, `Game`, `Slam`, `RoundResult`, `MatchEnd`) ayrı bir `.tscn` sahnesi olarak kurulabilir; bir `Autoload` (`ScreenManager`) `change_scene_to_packed` ile prototipteki `screen` state'inin karşılığını yönetir.
- **Fontlar:** Baloo 2 ve Nunito `.ttf`/`.woff2` dosyalarını Google Fonts'tan indirip proje `fonts/` klasörüne ekleyin, `FontFile` + `Theme` resource'u olarak tanımlayın.
- **Gradyanlı/parlaklıklı butonlar:** Godot'un `StyleBoxFlat`'ı düz renk + tek gölge destekler; buradaki diagonal gradyanlar için ya önceden export edilmiş bir gradyan texture (`StyleBoxTexture`) ya da basit bir `CanvasItem` shader (`linear gradient`) kullanılması önerilir. "Parlaklık" overlay'i ayrı bir yarı saydam `ColorRect`/`NinePatchRect` katmanı olarak eklenebilir.
- **Basma efekti (`scale(.92-.98)`):** `Button` üzerinde `Tween`/`AnimationPlayer` ile `pressed` sinyalinde scale animasyonu.
- **Dairesel sayaç:** `TextureProgressBar` (`fill_mode = RADIAL`) ile birebir karşılığı var; `value` alanı sunucudan gelen kalan süreye bağlanır.
- **HIMBIL nabız animasyonu:** `AnimationPlayer` içinde loop'lu scale + `modulate`/glow tween'i.
- **Kart uçuşma / el güncelleme:** `Tween.tween_property` ile pozisyon + `queue_free` / yeni `TextureRect` instance'ı.
- **Ağ/State entegrasyonu (kritik):** Bu prototipteki tüm `setState` çağrıları, gerçek uygulamada Colyseus'un `onStateChange` / şema senkronizasyonuyla değiştirilmelidir. Client hiçbir zaman "4'lü tamamlandı mı", "kim önce bastı" gibi kararları kendi vermemeli; yalnızca sunucudan gelen state'i (kılavuzun 3. ve 6. bölümlerindeki veri modeli) render etmelidir. Buton tıklamaları (`quickPlay`, `startGame`, kart seçme, HIMBIL) birer **intent mesajı** olarak WebSocket üzerinden sunucuya gönderilmeli.

## Varlıklar (Assets)

- Tüm ikonlar (logo, oyna/oda-kur/kodla-katıl, profil istatistik ikonları, alt menü, kart-sayısı rozeti, kupa) **inline SVG** olarak koda gömülüdür — ayrı bir dosya olarak dışa aktarmaya gerek yok, path verileri doğrudan `.dc.html` içinde görülebilir; Godot'ta `SVG` içe aktarımı ya da eşdeğer `Path2D`/ikon texture'ı olarak yeniden üretilebilir.
- Kart yüzü nesneleri şu an emoji (🍌🍇🍉🍊🍓) — bunlar **yer tutucudur**; gerçek üretimde kendi meyve/nesne illüstrasyon seti ile değiştirilmesi önerilir.
- Fontlar: Google Fonts "Baloo 2" ve "Nunito" (ikisi de OFL lisanslı, ticari kullanıma uygun).

## Sonraki Adım Önerisi

Kılavuzun "7. Geliştirme Aşamaları" bölümüne göre, bu tasarım **Aşama 2 (Tek kişilik + bot)** ve **Aşama 3 (Otoriter sunucu + 1 client)** sırasında UI/UX referansı olarak kullanılabilir. UI'ı bu tasarıma göre kurup, önce sahte/yerel state ile (Aşama 2), sonra gerçek Colyseus state'iyle (Aşama 3) bağlamanız önerilir.
