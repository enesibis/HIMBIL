# Handoff: Hımbıl — Açılış (Splash) Animasyonu

## Genel Bakış

Bu paket, kullanıcı ana ekrandaki **Hımbıl uygulama ikonuna dokunduğunda** oynayan açılış/splash animasyonunun tasarım referansıdır: logodaki 4 rengin tek bir "karışmış" lekeden ayrışıp (patlama efekti) Hımbıl logosunu oluşturması, ardından "Hımbıl" yazısının belirmesi ve son olarak giriş/karşılama ekranına geçiş.

Bu, `design_handoff_himbil_sicak_karnaval` paketindeki ana uçtan uca akışa **ek** bir parçadır — aynı Flutter istemcisine, uygulama ilk açıldığında (ana ekran → onboarding/giriş arasında) eklenecek bir geçiş katmanıdır.

## Tasarım Dosyaları Hakkında — ÖNEMLİ

Bu pakette bulunan `.dc.html` dosyası **HTML/React ile yapılmış bir tasarım referansıdır** — davranışı ve zamanlamayı göstermek için hazırlanmış tıklanabilir bir prototiptir, **doğrudan kopyalanacak üretim kodu değildir.** Gerçek istemci **Flutter** (Dart) ile yazılacağı için bu animasyonun Flutter'ın kendi animasyon sistemiyle (`AnimationController`, `Tween`, `AnimatedContainer` vb.) yeniden inşa edilmesi gerekir.

Prototipteki iOS ana ekranı (ikon grid'i, diğer uygulama ikonları) **sadece bağlamı göstermek için eklenmiş bir demo sahnesidir** — gerçek üründe zaten var olan cihazın kendi ana ekranıdır, yeniden inşa edilmesi gerekmez. Asıl inşa edilmesi gereken kısım, **ikona dokunma anından itibaren** oynayan splash animasyonu ve ardından gelen giriş ekranıdır.

## Fidelity

**Yüksek fidelity (hifi).** Renkler, boyutlar, zamanlama (ms) ve easing eğrileri nihai durumdadır — geliştirici bunları birebir hedefleyerek Flutter'da yeniden üretmelidir.

## Dosyalar

- `Acilis Animasyonu (tasarim referansi).dc.html` — tıklanabilir tasarım referansı. Tarayıcıda açıp ana ekrandaki Hımbıl ikonuna tıklayarak tüm akışı izleyebilirsiniz. Sağ üstteki "↺" ikonu (giriş ekranında) animasyonu sıfırlayıp tekrar oynatır.

## Ekranlar / Aşamalar

### 1. Ana Ekran (Home) — sadece bağlam
Cihazın kendi ana ekranı; Hımbıl ikonu krem (`#FBF3E4`) yuvarlatılmış kare (radius 16), içinde 4 renkli mini "confetti" şekli + altında "Hımbıl" etiketi. **Bu ekran gerçek üründe yok — sadece dokunma anını göstermek için demo'da var.**

### 2. Geçiş (Launch)
İkona dokunulduğunda ana ekran **260ms** içinde hafifçe büyüyerek (`scale(1.05)`) opaklığı 1→0 iner; aynı anda splash ekranı arkada belirmeye hazırlanır. Bu, iOS'un standart "uygulama açılıyor" hissini taklit eder.

### 3. Splash — Renk Patlaması (asıl animasyon)
- **t=0ms (splash'a giriş):** Ekran ortasında, 4 rengin karıştığı gradyanlı tek bir daire (58px çap) `scale(.25)`'ten `scale(1)`'e küçük bir "sekme" ile büyür (aşırı-esneme/overshoot easing, 320ms).
- **t≈190ms sonra (patlama tetiklenir):** Merkezdeki karışık daire **opaklık 300ms'de 0'a** iner; aynı anda **5 ayrı renkli parça** merkezden kendi nihai konumlarına doğru **700ms**'de, hafif geç başlayarak (0/40/80/120/160ms kademeli gecikme — "stagger") uçar:
  - Kırmızı yuvarlatılmış dikdörtgen `#E14B3B` → `translate(-30px,-34px) rotate(-12deg)`
  - Mavi yuvarlatılmış kare `#3B6EA5` → `translate(28px,-28px) rotate(45deg)`
  - Sarı blob `#F0A93B` (büyük) → `translate(-38px,10px) rotate(10deg)`
  - Yeşil daire `#3F8F6B` → `translate(16px,24px) rotate(0deg)`
  - Küçük sarı nokta `#F0A93B` (küçük) → `translate(-14px,38px) rotate(0deg)`
  - Easing: `cubic-bezier(.34, 1.56, .64, 1)` (Flutter karşılığı: `Curves.easeOutBack` veya benzeri overshoot eğrisi).
- **t≈810ms (parçalar yerleşince):** "Hımbıl" kelimesi (Baloo 2, 800, 32px, `#2E1D12`) **300ms**'de aşağıdan yukarı kayarak (`translateY(8px)→0`) ve opaklık 0→1 belirir.
- **~650ms bekleme** (kompozisyon ekranda sabit durur).

### 4. Giriş Ekranı (Entry)
Splash **400ms**'lik crossfade ile giriş ekranına geçer: küçük statik confetti logo + "Hımbıl" wordmark üstte, ortada "Hoş geldin!" başlığı + açıklama metni ("Kartları topla, rakiplerinden önce dörtlü yap."), altta tam genişlik "Devam Et" CTA (kırmızı gradyan, `himbil-proje-kilavuzu`'ndaki ana CTA stiliyle aynı). **Bu ekran, ana akıştaki onboarding/karşılama ekranına bağlanmalıdır** (`design_handoff_himbil_sicak_karnaval` paketindeki akışın başlangıcı).

## Zamanlama Özeti (ms)

| Aşama | Süre / gecikme |
|---|---|
| Ana ekran → splash geçişi | 260ms |
| Splash'a giriş → patlama tetiklenmesi | +190ms |
| Patlama (parçaların uçuşu) | 700ms (parça başına 40ms kademeli gecikme ile) |
| Patlama bitişi → wordmark belirmesi | +60ms, kendisi 300ms'de belirir |
| Wordmark sonrası bekleme | 650ms |
| Splash → giriş ekranı crossfade | 420ms |
| **Toplam (dokunma → giriş ekranı tam görünür)** | **~2.45 saniye** |

## Tasarım Token'ları

**Renkler (confetti / logo):**
- Kırmızı `#E14B3B` · Mavi `#3B6EA5` · Sarı/hardal `#F0A93B` · Yeşil `#3F8F6B`
- Karışık merkez daire: `linear-gradient(135deg, #E14B3B, #F0A93B 45%, #3F8F6B 75%, #3B6EA5)`
- Splash arkaplanı: `linear-gradient(165deg, #FDF8EE, #F6E9CE 60%, #EFD9AE)`
- Giriş ekranı arkaplanı: `#FDF8EE`
- Metin: ana `#2E1D12`, ikincil `#8A7660`

**Tipografi:** Başlıklar/wordmark **Baloo 2** (800), gövde **Nunito** (700) — proje genelindeki font çiftiyle aynı.

**Şekiller:** Her confetti parçası basit `border-radius`'lu dikdörtgen/kare/daire (SVG değil, düz şekil) — Flutter'da `Container` + `BoxDecoration(borderRadius:...)` veya `RRect` ile birebir karşılanır.

## Flutter'a Çeviri Notları

- **Genel yapı:** Tek bir `AnimationController` (toplam ~2.45s, ya da her aşama için ayrı controller'lar) ile yönetilecek bir `enum LaunchPhase { home, launch, splash, burst, entry }` state machine'i. Prototipteki `setTimeout` zinciri, Flutter'da `TickerProvider` + `Future.delayed` veya tek bir `AnimationController` üzerinde `Interval`'lerle tanımlanan alt animasyonlara karşılık gelir.
- **Merkez daire → parçalar:** Her parça için `AnimatedPositioned`/`Transform.translate` + `Tween<Offset>` (curve: `Curves.easeOutBack` ya da özel `Cubic(0.34, 1.56, 0.64, 1)`), `Interval(stagger, 1.0, curve: ...)` ile 5 parçaya kademeli gecikme verin.
- **Opaklık geçişleri:** `AnimatedOpacity` veya `FadeTransition`.
- **Ekranlar arası crossfade:** `AnimatedSwitcher` veya iki `Stack` katmanı + `AnimatedOpacity` (splash çıkarken, giriş girerken).
- **Tekrar oynatma / reset:** Prototipteki "↺" sadece tasarım incelemesi için eklenmiş bir demo kolaylığıdır, gerçek üründe gerekmez — animasyon uygulama her açıldığında bir kez oynar.
- **Performans notu:** Splash tamamen deklaratif/timer bazlı olduğundan sunucu bağlantısı beklemeden oynatılabilir; gerçek ağ/oturum başlatma (auth, Colyseus bağlantısı vb.) bu animasyonla **paralel** başlatılıp, animasyon bittiğinde oturum hazır değilse giriş ekranında kısa bir yükleniyor durumu gösterilmesi önerilir.

## Varlıklar

Ek görsel varlık yok — tüm şekiller düz renkli geometrik formlardır (daire, yuvarlatılmış dikdörtgen), kod içinde üretilmiştir; ayrıca dışa aktarılacak bir dosya yoktur.

## Sonraki Adım Önerisi

Bu animasyonu, `design_handoff_himbil_sicak_karnaval` paketindeki **Ana Menü** ekranından **önce**, uygulamanın ilk açılışında (cold start) bir kerelik gösterilecek şekilde entegre edin. Onboarding'i daha önce tamamlamış kullanıcılar için "Giriş Ekranı" yerine doğrudan Ana Menü'ye yönlendirme yapılabilir.
