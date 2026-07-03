# Hımbıl — Kart Sanatı Paketi

Uygulamaya özel çizilmiş kart görselleri. Tümü vektör (SVG), her boyutta net görünür.

## İçerik

- `meyveler/` — kart ön yüzü meyve ikonları, 5 adet (48x48 viewBox)
- `kart-sirtlari/` — markete koyulacak kart sırtı tasarımları, 15 adet (60x84 viewBox, 5:7 kart oranı)
- `kart-sanati.js` — aynı görsellerin ES module hali (string olarak) + fiyat listesi

## Kart sırtları ve önerilen fiyatlar

| id | İsim | Jeton |
|----|------|-------|
| klasik | Klasik | 0 (varsayılan) |
| karnaval | Karnaval | 0 (varsayılan) |
| retro | Retro Şerit | 200 |
| karpuz | Karpuz Dilimi | 250 |
| limonata | Limonata | 250 |
| cilek | Çilek Reçeli | 300 |
| petek | Bal Peteği | 300 |
| tutti | Meyve Şöleni | 350 |
| uykucu | Uykucu Hımbıl | 400 |
| kilim | Anadolu Kilim | 450 |
| gece | Gece Pazarı | 450 |
| nazar | Nazar Boncuğu | 500 |
| altin | Altın Varak | 500 |
| yildiz | Yıldız Tozu | 750 |
| elmas | Elmas | 900 |

## Kullanım

### Doğrudan SVG dosyası
```html
<img src="kart-sirtlari/nazar.svg" width="70" height="98" />
```

### JS module ile
```js
import { FRUIT_SVG, CARD_SKINS, dataUri } from './kart-sanati.js';

// img src olarak
img.src = dataUri(FRUIT_SVG.banana);

// ya da inline
container.innerHTML = CARD_SKINS.find(s => s.id === 'nazar').svg;
```

### React Native
`react-native-svg` + `SvgXml` ile string halini doğrudan kullanabilirsiniz:
```jsx
<SvgXml xml={FRUIT_SVG.strawberry} width={48} height={48} />
```

## Notlar

- Kart sırtı çizimleri 60x84 viewBox'a göre; kartınız hangi boyutta olursa olsun `width/height` verin, oranı 5:7 tutun.
- Köşe yuvarlaklığı çizimin içinde (rx=11). Kart konteynerinize ayrıca `border-radius` + `overflow:hidden` uygularsanız birebir oturur.
- Renkler uygulamanın sıcak karnaval paletinden: #E14B3B, #F0A93B, #2F9C8F, #8E5FC7, #FBF3E4.
