# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Hımbıl is a real-time multiplayer mobile card game (Turkish traditional game, aka "Bom"). Full technical roadmap, architecture rationale, and stage-by-stage progress live in `docs/himbil-proje-kilavuzu.md` (Turkish) — read it before making architectural decisions; it's the source of truth for *why*, this file is the source of truth for *how to work in the repo*.

The repo is a monorepo with two independent codebases that don't talk to each other *at runtime* yet:

- `server/` — Node/TypeScript authoritative Colyseus game server. The Stage 3 server side is implemented and runnable (`npm run dev`, port 2567): `server/rooms/HimbilRoom.ts` (Colyseus room, `filterBy(["roomCode"])` matchmaking) wraps the authoritative loop in `server/rooms/gameSession.ts`; `server/schema/messages.ts` defines the wire messages; `server/persistence/` holds the SQLite guest-account/token store; `server/routes/` has guest + (token-gated) monitor endpoints.
- `client-flutter/` — the Flutter mobile client (Stage 1-2 complete). The game screens still run fully self-contained: local rules against bot opponents. A tested networking layer exists in `lib/net/` (hand-rolled subset of the Colyseus wire protocol + msgpack, reconnect-token support, deep links) but **no screen consumes it yet** — wiring the UI to server state is the remaining half of Stage 3.

## Commands

### Server (`server/`)
```
npm test          # vitest run — full suite
npm run test:watch
npx vitest run server/game/__tests__/swap.test.ts   # single file
npx vitest run -t "test name substring"             # single test by name
npm run build     # tsc
npm run dev       # run the Colyseus server locally (tsx watch, ws://localhost:2567)
npm run lint      # eslint
```

### Client (`client-flutter/`)
```
flutter analyze
flutter test                              # full suite
flutter test test/widget_test.dart        # single file
flutter run -d <device_id>                # flutter devices / flutter emulators to list
flutter build apk --release               # produces build/app/outputs/flutter-apk/app-release.apk
```
Widget tests must set a realistic portrait phone surface size before pumping any screen beyond the home screen — the `flutter_test` default (800x600, landscape-shaped) doesn't match the app's portrait-only layouts and will produce spurious `RenderFlex overflowed` failures on the game screen. See `_setPhoneSize` in `test/widget_test.dart`.

## Architecture

### The rule engine is ported twice, independently
The core game logic (deck/deal/swap/quartet-detection/scoring) exists in **two parallel implementations** with no shared code: `server/game/*.ts` (network-independent, unit-tested, now also wrapped by the Colyseus room via `server/rooms/gameSession.ts`) and `client-flutter/lib/game/{rules,game_controller,bot_ai}.dart` (a from-scratch Dart port used to drive the current bot-only client). They must be reasoned about independently — a rule change on one side does not propagate to the other, but `client-flutter/test/rules_test.dart` mirrors the server's rule-engine test suite as parity tests, so a divergence should fail there first. Once the screens are wired to server state (the remaining half of Stage 3), the client's local copy is meant to shrink to an offline/bot mode, not kept in permanent parallel as the default.

Known divergence between the two ports: the server's object pool (`server/game/deck.ts`) supports up to 12 object types for variable player counts; the Dart port (`Rules.objectPool` in `rules.dart`) hardcodes the 4 needed for `GameController.numPlayers = 4` (the only player count the client currently supports).

### Server-authoritative design (server side built, client not yet wired)
The intended end-state architecture (see kılavuz §3) is strict server authority: clients send intent only, never compute results, and never see other players' hands. The server side of this now exists (`server/rooms/gameSession.ts` runs the authoritative loop; `HimbilRoom` pushes each player a filtered view), and `lib/net/himbil_net_client.dart` can talk to it — but the *screens* still run on `GameController` (Dart), which computes everything locally including bot decisions (`bot_ai.dart`). Don't take the client's local computation as the target architecture; it's the Stage 2 stand-in that becomes the offline/bot mode once screens consume `HimbilNetClient.stateUpdates`.

### Card pass model: synchronized swap tick
The game uses "Model A" from the kılavuz: hand size is always fixed at 4, and every player's chosen (or timed-out/random) card is exchanged **simultaneously** on a fixed-cadence tick (`GameController.swapTickDuration`, `server/game/swap.ts`'s `resolveSwapTick`), not on-demand per player action. This is deliberate — it's what makes "you must pass before you can slam" hold without special-casing it, and it's why the client's pass-relay flight animation (`FlyingCard`/`CardFanPulse` in `game_screen.dart`) is a *presentation-only* sequential animation layered on top of a data update that actually happens all at once; it does not change tick timing.

### Slam window and scoring
Once any hand completes a quartet, a slam window opens; presses inside it are scored by arrival order (100, 75, 50, 25...). A false slam (pressing with no quartet anywhere) is penalized. `GameController.submitHumanSlam` additionally guards against a specific exploit: a player who does not personally hold the quartet cannot be the *first* recorded press in the window (their press is a no-op until someone else — the real holder — has already slammed), and the UI (`game_screen.dart`'s `_humanHasQuartet` check) never reveals that a window is open unless the human's own hand is the quartet. Preserve both guards if you touch this path — the naive implementation (any press during the window counts) is trivially exploitable by mashing the button blind.

### Design handoff workflow
`design/design_handoff_*/` folders are hifi HTML/JS prototypes (not production code) delivered as pixel-perfect references — each has its own `README.md` with exact colors, spacing, and animation keyframe timings. The expected workflow is to reimplement them idiomatically in Flutter (not copy markup), matching the numbers precisely. `design/design_handoff_himbil_sicak_karnaval` is the base visual direction ("Sıcak Karnaval" / Warm Carnival: saturated red/mustard, Baloo 2 + Nunito) that `client-flutter/lib/theme/{palette,text_styles}.dart` encodes as reusable tokens; later handoffs (onboarding, splash animation, card designs) build on top of it and should reuse those tokens rather than hardcoding new colors.

Baloo2 and Nunito are variable fonts (single `.ttf`, `wght` axis) — weight is selected at render time via `fontVariations` in `AppText` (`text_styles.dart`), not via multiple pubspec `weight:` entries pointing at the same file (that was tried, doesn't work, was removed).
