# Hımbıl

Hımbıl ("Bom" olarak da bilinir), gerçek zamanlı çok oyunculu bir mobil kart oyunu. Proje şu an iki bağımsız codebase içeren bir monorepo:

- **`client-flutter/`** — Flutter mobil istemci. Online maçlar uçtan uca çalışır: lobi sunucuya bağlanır (oda kur / kodla katıl / hızlı eşleşme), oyun ekranı sunucudan gelen otoriter state'i oynatır, kopuşta otomatik yeniden bağlanır. Sunucuya ulaşılamazsa botlarla oynanan tam offline moda düşer — offline mod her zaman çalışan tabandır.
- **`server/`** — Node/TypeScript yetkili Colyseus oyun sunucusu. Kural motoru (`server/game/`), oyun odası (`server/rooms/HimbilRoom.ts` + `gameSession.ts`), mesaj şeması (`server/schema/`), misafir hesap/jeton deposu (`server/persistence/`, SQLite) ve çalıştırılabilir giriş noktası (`index.ts`) hazır; `npm run dev` ile ayağa kalkar (varsayılan `ws://localhost:2567`).

Oyun kuralları her iki tarafta da ayrı ayrı (Dart ve TypeScript) implemente edilmiş durumda ve `client-flutter/test/rules_test.dart` parity testleriyle senkron tutuluyor; online modda kural hesabının tamamı sunucuda koşar, yerel kopya offline/bot modudur.

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
npm run dev        # sunucuyu lokal çalıştır (tsx watch, ws://localhost:2567)
npm start          # derlenmiş sunucuyu çalıştır (önce npm run build)
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
client-flutter/   Flutter mobil istemci (offline bot modu + online Colyseus istemcisi)
server/           Node/TypeScript Colyseus sunucusu (oda, misafir hesap defteri, analytics, liderlik)
design/           Hifi HTML/JS tasarım referansları (design/design_handoff_*)
docs/             Proje kılavuzu ve yapılacaklar listesi
```
