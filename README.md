# Hımbıl

Hımbıl ("Bom" olarak da bilinir), gerçek zamanlı çok oyunculu bir mobil kart oyunu. Proje şu an iki bağımsız codebase içeren bir monorepo:

- **`client-flutter/`** — Flutter mobil istemci. Oyun ekranları şu an yerel kural motoruyla bot rakiplere karşı çalışıyor (tam offline oynanabilir). Sunucuya bağlanacak ağ katmanı (`lib/net/` — Colyseus wire protokolü, reconnect, deep link) yazıldı ve test edildi, ancak ekranlara henüz bağlanmadı.
- **`server/`** — Node/TypeScript yetkili Colyseus oyun sunucusu. Kural motoru (`server/game/`), oyun odası (`server/rooms/HimbilRoom.ts` + `gameSession.ts`), mesaj şeması (`server/schema/`), misafir hesap/jeton deposu (`server/persistence/`, SQLite) ve çalıştırılabilir giriş noktası (`index.ts`) hazır; `npm run dev` ile ayağa kalkar (varsayılan `ws://localhost:2567`).

İki codebase çalışma zamanında henüz birbiriyle konuşmuyor (ekran–sunucu bağlama işi Aşama 3'ün kalan yarısı); oyun kuralları her iki tarafta da ayrı ayrı (Dart ve TypeScript) implemente edilmiş durumda ve `client-flutter/test/rules_test.dart` parity testleriyle senkron tutuluyor.

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
client-flutter/   Flutter mobil istemci (Aşama 1-2 tamam; ağ katmanı hazır, ekran bağlama bekliyor)
server/           Node/TypeScript Colyseus sunucusu (Aşama 3 sunucu tarafı hazır)
design/           Hifi HTML/JS tasarım referansları (design/design_handoff_*)
docs/             Proje kılavuzu ve yapılacaklar listesi
```
