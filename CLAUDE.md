# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Hımbıl is a real-time multiplayer mobile card game (Turkish traditional game, aka "Bom"). Full technical roadmap, architecture rationale, and stage-by-stage progress live in `docs/himbil-proje-kilavuzu.md` (Turkish) — read it before making architectural decisions; it's the source of truth for *why*, this file is the source of truth for *how to work in the repo*.

The repo is a monorepo with two independent codebases that don't talk to each other yet:

- `server/` — Node/TypeScript, will become the authoritative Colyseus game server (Stage 3+, not started: `server/rooms/` and `server/schema/` are empty).
- `client-flutter/` — the Flutter mobile client (Stage 1-2, in progress). Currently fully self-contained: it runs the game rules locally against bot opponents, with no networking.

## Commands

### Server (`server/`)
```
npm test          # vitest run — full suite
npm run test:watch
npx vitest run server/game/__tests__/swap.test.ts   # single file
npx vitest run -t "test name substring"             # single test by name
npm run build     # tsc
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
The core game logic (deck/deal/swap/quartet-detection/scoring) exists in **two parallel implementations** with no shared code: `server/game/*.ts` (network-independent, unit-tested, meant to eventually run inside a Colyseus room) and `client-flutter/lib/game/{rules,game_controller,bot_ai}.dart` (a from-scratch Dart port used to drive the current bot-only client). They must be reasoned about independently — a rule change on one side does not propagate to the other. When Stage 3 (Colyseus integration) lands, the client's local copy is meant to be deleted and replaced with real server state, not kept in permanent parallel.

Known divergence between the two ports: the server's object pool (`server/game/deck.ts`) supports up to 12 object types for variable player counts; the Dart port (`Rules.objectPool` in `rules.dart`) hardcodes the 4 needed for `GameController.numPlayers = 4` (the only player count the client currently supports).

### Server-authoritative design (target, not yet wired up)
The intended end-state architecture (see kılavuz §3) is strict server authority: clients send intent only, never compute results, and never see other players' hands. The *current* client violates this by necessity — it has no server to defer to, so `GameController` (Dart) computes everything locally, including bot decisions (`bot_ai.dart`). Don't take the current client's local computation as the target architecture; it's a stand-in for Stage 2.

### Card pass model: synchronized swap tick
The game uses "Model A" from the kılavuz: hand size is always fixed at 4, and every player's chosen (or timed-out/random) card is exchanged **simultaneously** on a fixed-cadence tick (`GameController.swapTickDuration`, `server/game/swap.ts`'s `resolveSwapTick`), not on-demand per player action. This is deliberate — it's what makes "you must pass before you can slam" hold without special-casing it, and it's why the client's pass-relay flight animation (`FlyingCard`/`CardFanPulse` in `game_screen.dart`) is a *presentation-only* sequential animation layered on top of a data update that actually happens all at once; it does not change tick timing.

### Slam window and scoring
Once any hand completes a quartet, a slam window opens; presses inside it are scored by arrival order (100, 75, 50, 25...). A false slam (pressing with no quartet anywhere) is penalized. `GameController.submitHumanSlam` additionally guards against a specific exploit: a player who does not personally hold the quartet cannot be the *first* recorded press in the window (their press is a no-op until someone else — the real holder — has already slammed), and the UI (`game_screen.dart`'s `_humanHasQuartet` check) never reveals that a window is open unless the human's own hand is the quartet. Preserve both guards if you touch this path — the naive implementation (any press during the window counts) is trivially exploitable by mashing the button blind.

### Design handoff workflow
`design/design_handoff_*/` folders are hifi HTML/JS prototypes (not production code) delivered as pixel-perfect references — each has its own `README.md` with exact colors, spacing, and animation keyframe timings. The expected workflow is to reimplement them idiomatically in Flutter (not copy markup), matching the numbers precisely. `design/design_handoff_himbil_sicak_karnaval` is the base visual direction ("Sıcak Karnaval" / Warm Carnival: saturated red/mustard, Baloo 2 + Nunito) that `client-flutter/lib/theme/{palette,text_styles}.dart` encodes as reusable tokens; later handoffs (onboarding, splash animation, card designs) build on top of it and should reuse those tokens rather than hardcoding new colors.

Baloo2 and Nunito are variable fonts (single `.ttf`, `wght` axis) — weight is selected at render time via `fontVariations` in `AppText` (`text_styles.dart`), not via multiple pubspec `weight:` entries pointing at the same file (that was tried, doesn't work, was removed).
