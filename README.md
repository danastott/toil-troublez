# Toil & Troublez

A digital adaptation of the push-your-luck card game *Toil and Troublez*
(Grandpa Beck's Games). Hunt for Talismans in the Enchanted Forest during the
witching hour: draw, place, and push your luck — or stop while you're ahead.

## Game

- 2–6 players, first to an empty deck (with one reshuffle allowance for
  4–6 players) wins on points.
- Each turn: draw a Talisman and place it in a forest row — ascending numbers,
  no two of the same Talisman in a row, no adjacent cards of the same colour.
  Then keep drawing or bank the row.
- A row with no legal play busts: bank it, and take one card from the forest.
- Finished rows score 1 pt per card, plus 10 pts per Collection (all five
  Talismans, or four of a kind).
- Master Magician spells: **Vanish** (erase a Talisman from a finished row),
  **Summon** (steal a card), **Poison** (force a discard), **Cloak**
  (hide a card from the colour rule).

## Modes

- **Single Player** — play against up to two bots with Amateur, Skilled or
  Master skill.
- **Pass & Play** — up to six local players around one device, with a
  hand-hiding veil between turns.
- **Host a Game** / **Join a Game** — networked play over the LAN: UDP
  discovery broadcasts the lobby, connections run over WebSockets, and the
  host runs the authoritative engine.

## Layout

- `lib/game/` — the rules: `rules.dart` (placement/collection legality),
  `engine.dart` (state machine), `cards.dart` (the 83-card deck),
  `bot.dart` (the three bot skills).
- `lib/session/` — `GameSession`: one device's view of a game in any mode.
- `lib/net/` — discovery (UDP), lobby protocol and host/client sessions.
- `lib/ui/` — screens, theme and the illustrated card/icon painters.

## Develop

```sh
flutter test          # protocol and widget tests
flutter run -d macos  # or ios / android
```

`tool/` holds standalone stress harnesses (full-game engine sanity, skill
sweeps, a host+client protocol smoke): `bot_smoke`, `sweep` and
`smoke_game` run with `dart run tool/<name>.dart`; `net_smoke` (imports the
sessions) runs with `flutter test tool/net_smoke.dart`.
