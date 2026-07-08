# Hımbıl

Hımbıl ("Bom" olarak da bilinir), gerçek zamanlı çok oyunculu bir mobil kart oyunu. Proje şu an iki bağımsız codebase içeren bir monorepo:

- **`client-flutter/`** — Flutter mobil istemci. Şu an tamamen kendi başına çalışıyor: oyun kurallarını yerelde çalıştırıp bot rakiplere karşı oynatıyor, ağ bağlantısı yok.
- **`server/`** — Node/TypeScript ile yazılan, ileride yetkili Colyseus oyun sunucusu olacak katman. Kural motoru (`server/game/`) test edilmiş durumda; `server/rooms/` ve `server/schema/` henüz boş (Aşama 3 başlamadı).

İki codebase şu an birbiriyle konuşmuyor; oyun kuralları her iki tarafta da ayrı ayrı (Dart ve TypeScript) implemente edilmiş durumda.

Mimari kararların gerekçesi ve aşama aşama yol haritası için bkz. [docs/himbil-proje-kilavuzu.md](docs/himbil-proje-kilavuzu.md) (Türkçe, kapsamlı). Yapılacaklar listesi için bkz. [docs/yapilmasi-gerekenler.md](docs/yapilmasi-gerekenler.md).

## Kurulum ve komutlar

### Sunucu (`server/`)

Node.js >= 22 gerekli.

```bash
cd server
npm install
npm test          # vitest run — tüm test paketi
npm run test:watch
npm run lint       # eslint
npm run format     # prettier
npm run build      # tsc
```

Tek bir test dosyası veya isme göre test çalıştırmak için:

```bash
npx vitest run server/game/__tests__/swap.test.ts
npx vitest run -t "test adı alt dizesi"
```

### İstemci (`client-flutter/`)

Flutter SDK gerekli (bkz. [client-flutter/pubspec.yaml](client-flutter/pubspec.yaml) için sürüm kısıtı).

```bash
cd client-flutter
flutter pub get
flutter analyze
flutter test                              # tüm test paketi
flutter test test/widget_test.dart        # tek dosya
flutter devices                           # veya flutter emulators
flutter run -d <device_id>
flutter build apk --release               # build/app/outputs/flutter-apk/app-release.apk
```

Release imzası için `client-flutter/android/key.properties.example` şablonuna bakın.

## Repo yapısı

```
client-flutter/   Flutter mobil istemci (Aşama 1-2, sürüyor)
server/           Node/TypeScript oyun sunucusu (Aşama 3+, kural motoru hazır)
design/           Hifi HTML/JS tasarım referansları (design/design_handoff_*)
docs/             Proje kılavuzu ve yapılacaklar listesi
```
