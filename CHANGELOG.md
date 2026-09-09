# Changelog

Changes **this distribution** makes on top of
[ehsanmok/flare](https://github.com/ehsanmok/flare). Upstream's own history is
the commit log; nothing here restates it.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.10.0] - 2026-09-08

First published build. Tracks upstream **flare 0.10.0** (`c6f0084`).

### Carried from open upstream pull requests

Merged here only because magmalake needs them before review completes upstream.
Each should be dropped from this repository the moment it lands there.

- [#11](https://github.com/ehsanmok/flare/pull/11) — expose the handshake
  `Origin` on `WsConnection`.
- [#14](https://github.com/ehsanmok/flare/pull/14) — bound body reads, not just
  connect.
- [#15](https://github.com/ehsanmok/flare/pull/15) — serve HTTP and WebSocket on
  one port.
- [#16](https://github.com/ehsanmok/flare/pull/16) — opt-in `ws_offload`, one
  thread per WebSocket.

`#11` and `#15` both add a field to `WsConnection` and so conflicted with each
other rather than with upstream. Resolved by keeping both: the prebuf
constructor also takes `origin` (defaulted), so every field is initialized on
both constructors. `pixi.toml`'s aggregate `tests` task is the union of the
branches' test steps.

### Packaging

- **Mojo pin widened** from `>=1.0.0,<1.1.0` to `>=1.0.0,<1.2.0`, so one
  published build serves consumers on both Mojo 1.0.0 and the 1.1.0.dev
  nightlies. `flare.net`, `flare.http`, `flare.http2`, `flare.tls`, `flare.ws`
  and `flare.grpc` were each verified to compile clean on 1.0.0 (`ed45d567`)
  and 1.1.0.dev2026090705 (`6930d976`).
- Upstream's `README.md` preserved verbatim as `README.upstream.md`; the new
  `README.md` explains what this repository is and points at upstream.

### Not changed

- The module is still imported as `flare`, not `flare_mlake`. Only the *package*
  is renamed, so switching to an official flare package later is a one-line
  dependency change rather than a source-wide rename.
- `LICENSE` is upstream's, unmodified (MIT, © 2025 Ehsan M. Kermani).
- The `.so` filename in the recipe is left alone. It matches
  `flare.utils.dylib.find_flare_lib`, which looks for `.so` on every platform,
  and `dlopen` ignores the extension on macOS — the two are consistent and
  changing one without the other would break it.
