# Handoff: Hımbıl — 4 Oyunculu Masa Düzeni, Kart Tasarımları ve Pas Animasyonları

## Genel Bakış
Hımbıl (geleneksel Türk kağıt oyunu) mobil oyununun **oyun masası ekranı**: 4 oyunculu oturma düzeni (Güney = oyuncu, Doğu/Kuzey/Batı = rakipler), yenilenmiş kart tasarımları (açık el kartları + kapalı rakip kartları) ve **sıralı kart pas animasyonu** (Güney→Doğu→Kuzey→Batı→Güney zinciri).

Bu paket önceki handoff'ların (Sıcak Karnaval görsel yönü, açılış animasyonu, avatar seti) devamıdır ve oyun masası etkileşimlerine odaklanır.

## Tasarım Dosyaları Hakkında
Bu paketteki dosyalar **HTML ile hazırlanmış tasarım referanslarıdır** — amaçlanan görünümü ve davranışı gösteren prototiplerdir, doğrudan kopyalanacak üretim kodu değildir. Görev: bu tasarımları hedef kod tabanının mevcut ortamında (React Native, Flutter, Unity, SwiftUI vb.) o ortamın yerleşik kalıpları ve kütüphaneleriyle **yeniden oluşturmak**. Henüz bir ortam yoksa proje için en uygun framework'ü seçip orada uygulayın.

## Fidelity (Sadakat Düzeyi)
**High-fidelity (hifi)**: Renkler, tipografi, boşluklar, kart boyutları ve animasyon zamanlamaları kesindir. UI, kod tabanının kendi araçlarıyla pixel-perfect yeniden üretilmelidir.

## Ekran: Oyun Masası (4 Oyunculu)

### Oturma Düzeni
Dairesel pas yönü **sağa doğrudur** (saat yönünün tersi görünümde ekranda):
**Güney (sen) → Doğu → Kuzey → Batı → Güney**

- **Kuzey (üst, orta)**: Avatar (36×36, yuvarlak, 2px mavi degrade çerçeve `linear-gradient(160deg,#5B8FC7,#3B6EA5)`) + isim yan yana; altında 4 kapalı kart yatay yelpaze halinde: rotasyonlar `-8°, -2°, 3°, 9°`, her kart bir öncekinin üzerine `margin-left:-18px` ile biner, z-index soldan sağa artar.
- **Batı (sol kenar, dikey)**: Avatar (36×36) + isim (11px, tek satır ellipsis, max 70px) + 4 kapalı kart **dikey dağınık yelpaze**: konteyner 60×132px, kartlar absolute konumlu, `top: 2/24/46/68px`, `left: 14/12/15/13px`, rotasyonlar `82°, 88°, 93°, 99°` (90°'ye yakın ama düzensiz — "karışık" görünüm).
- **Doğu (sağ kenar, dikey)**: Batı ile aynı, rotasyonlar negatif: `-82°, -88°, -93°, -99°`.
- **Güney (alt)**: Oyuncunun 4 açık kartı yan yana (`display:flex; gap:9px`), altında büyük yuvarlak HIMBIL butonu.
- Yan kolonlar 74px genişliğinde; orta alan (zamanlayıcı + tur etiketi) `flex:1`.
- Diğer oyuncu sayılarında (3/5/6) eski düzen kullanılır: rakipler üstte tek sıra halinde.

### Kapalı Kart (Rakip Kartı) Tasarımı
- Boyut: **36×50px**, `border-radius:9px`
- Kenarlık: `2px solid #B93424`
- Zemin: `linear-gradient(160deg, #FF6F5A, #D6432F)`
- İç altın çerçeve: `box-shadow: inset 0 0 0 2px rgba(240,169,59,.55), 0 3px 6px rgba(46,29,18,.15)`
- Üst parlaklık bandı: üstten %45 yükseklikte `linear-gradient(180deg, rgba(255,255,255,.35), transparent)` overlay
- Ortada amblem: beyaz çift-kart ikonu (15×15 SVG — arkadaki kart %55 opaklık, -10° döndürülmüş; öndeki tam beyaz)
- `overflow:hidden` (parlaklık bandı köşelerden taşmasın)

### Açık Kart (Oyuncu Eli) Tasarımı
- Boyut: **70×96px**, `border-radius:16px`, `border:3px solid #E14B3B`
- Zemin: `linear-gradient(160deg, cardBg, cardBg2)` (krem tonları — mevcut tema değişkenleri)
- İç altın çerçeve: `inset 0 0 0 2px rgba(240,169,59,.35)` + `0 6px 0 rgba(46,29,18,.08), 0 10px 18px rgba(46,29,18,.08)`
- Üst parlaklık bandı: %38 yükseklik, `rgba(255,255,255,.4) → transparent`
- Ortada meyve SVG (muz #FFCB3D, üzüm #9B59D0, karpuz #3F8F4F/#F0455C, portakal #F4941E, çilek #F0455C)
- **Köşe işaretleri**: sol-üst ve sağ-alt köşede 8×8px, `border-radius:3px`, meyvenin ana rengiyle dolu (klasik iskambil köşe pip'i hissi)
- Seçili kart: `translateY(-14px) scale(1.06)`, `transition: transform .2s`

## Etkileşimler ve Animasyonlar

### Sıralı Pas Zinciri (kritik!)
Oyuncu bir kart seçtiğinde (veya süre dolduğunda rastgele kart) **sıralı** bir zincir çalışır — hepsi aynı anda DEĞİL:

1. **Aşama "out" (420ms)**: Seçilen kart Doğu'ya doğru uçar — `cardFlyOutSelf`: `translate(130px,-50px) scale(.45) rotate(20deg)` + opacity→0, `ease`, `forwards`. Aynı anda **Doğu** yığını pulse yapar.
2. **Aşama "relayNorth" (340ms)**: Doğu kartı Kuzey'e verir → **Kuzey** yığını pulse. Bu anda oyuncunun eli yeni kartla güncellenir ama gelen kart hâlâ `opacity:0` (gizli).
3. **Aşama "relayWest" (340ms)**: Kuzey kartı Batı'ya verir → **Batı** yığını pulse.
4. **Aşama "in" (380ms)**: Batı oyuncuya verir — yeni kart soldan uçarak gelir: `cardFlyInSelf`: `translate(-130px,-50px) scale(.45) rotate(-18deg)` → normale, `cubic-bezier(.2,.8,.3,1)`. Batı pulse'ı bu aşamada da sürer.

Pulse keyframe: `stackPulse`: `scale(1) → scale(1.16) + brightness(1.3) → scale(1)`, süreler: doğu .42s, kuzey/batı .34s.

- Zincir sürerken geri sayım zamanlayıcısı **duraklatılır**; zincir bitince tick ilerler, süre sıfırlanır (`TICK_DURATION`), zamanlayıcı yeniden başlar.
- Kart seçimi: tıklamada önce 300ms "kalkma" (lift), sonra zincir başlar. Zincir sürerken yeni seçim engellenir.
- 3 pas tamamlanınca `phase: 'ready'` → "4'lün tamam — HIMBIL'e bas!" mesajı.

### Keyframe'ler (CSS)
```css
@keyframes cardFlyOutSelf{0%{transform:translateY(0) scale(1) rotate(0);opacity:1}100%{transform:translate(130px,-50px) scale(.45) rotate(20deg);opacity:0}}
@keyframes cardFlyInSelf{0%{transform:translate(-130px,-50px) scale(.45) rotate(-18deg);opacity:0}100%{transform:none;opacity:1}}
@keyframes stackPulse{0%,100%{transform:scale(1);filter:brightness(1)}50%{transform:scale(1.16);filter:brightness(1.3)}}
```

## State Yönetimi
- `passAnim: null | { idx, stage }` — stage: `'out' | 'relayNorth' | 'relayWest' | 'in'`. Zincir setTimeout'larla ilerler; her adımda ekran hâlâ oyun ekranı mı diye kontrol edilir.
- `hand: string[4]`, `selected: number|null`, `tick: 0-3`, `phase: 'swap'|'ready'`, `timeLeft`, `round`.
- Zamanlayıcı 100ms interval; `passAnim` doluyken azalmaz.

## Design Tokens
- Kart arkası kırmızıları: `#FF6F5A → #D6432F` (degrade), kenar `#B93424`
- Vurgu kırmızısı: `#E14B3B`; altın: `#F0A93B` (`rgba(240,169,59,…)`)
- Avatar çerçeve mavisi: `#5B8FC7 → #3B6EA5`
- Metin: koyu kahve `#2E1D12` ağırlıklı (tema değişkeni), soluk metin muted tonu
- Fontlar: **Baloo 2** (başlık/sayı, 700-800), **Nunito** (gövde/isim, 700-800)
- Meyve renkleri: muz `#FFCB3D`, üzüm `#9B59D0`, karpuz `#3F8F4F` + `#F0455C`, portakal `#F4941E`, çilek `#F0455C`

## Assets
- Avatarlar: `avatars/` klasöründeki SVG data-URI üretimli karakterler (kod içinde `avImgRef` ile bağlanır) — hedef uygulamada gerçek avatar görselleriyle değiştirilecek.
- Tüm kart görselleri ve ikonlar saf CSS + inline SVG'dir; harici görsel yoktur.

## Dosyalar
- `Himbil Prototip.dc.html` — tüm prototip. Oyun masası bölümü: `isGame` bloğu (şablonda `a.isFourPlayerLayout` ile 4'lü düzen), pas mantığı: `beginPass()`, `onCardTap()`, `startTimer()` metodları; kart stilleri `hand` map'i ve kapalı kart div'lerinde inline'dır.
