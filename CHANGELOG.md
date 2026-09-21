# Changelog

Changes **this distribution** makes on top of
[ehsanmok/flare](https://github.com/ehsanmok/flare). Upstream's own history is
the commit log; nothing here restates it.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.10.2] - 2026-09-21

Tracks upstream **flare main** at `c3dc933`, 72 commits past `1e92aa3`,
including upstream's own move to Mojo 1.1.0 (`f6b5b16`).

### Changed
- **Mojo 1.1.0.** `mojo >=1.1.0,<2.0.0` in both `pixi.toml` and the recipe.
  The widened `>=1.0.0,<1.2.0` pin this distribution carried is gone: it
  existed so magmalake repos could build flare from one source tree on both
  1.0.0 and the nightlies, and the whole org is on 1.1.0 now. Upstream's
  `Atomic[T]` spelling requires it in any case.
- `json_mlake >=0.4.0,<0.5` and `threads-mojo >=0.6.0,<0.7`, both the Mojo
  1.1.0 releases of those tins.
- Takes upstream's build of `libflare_zlib.so` in the recipe. Its absence was
  not a build error, only a runtime one at the first compressed response, so
  this distribution had been shipping without it.

### Removed — deltas upstream has absorbed
- **The `nanosleep` fix.** `flare/runtime/_libc_time.mojo` calling
  `std.time.sleep` instead of declaring its own `nanosleep` extern is
  upstream's own code now, so this is no longer a delta to hand-merge.
- **The build-backend pin.** This fork tracked `0.4.*` to escape upstream's
  unsolvable `==0.3.13`; upstream now takes `>=0.3.13`, which is the better
  fix — a backend declares the `pixi-build-api-version` it speaks, so the
  range lets the solver match backend to client.
- The pre-review copies of the gRPC-compression and HTTP/2 bulk-copy work
  (this fork's #3 and #4) are superseded by upstream's reviewed #29 and #30.

### Kept — deltas that still stand
- `flare/runtime/_thread.mojo` as an adapter over threads.mojo. Upstream
  still binds `pthread_*` itself, and exactly one library may bind a given
  libc symbol or Mojo refuses to lower.
- The macOS shared-listener default in `flare/runtime/scheduler.mojo`: BSD's
  `SO_REUSEPORT` does not load-balance, so per-worker listeners are a
  pessimisation there.
- `json_mlake` / `mozz_mlake` instead of upstream's `json` / `mozz`, so a
  consumer resolves one org's packages. (The old reason — their unsolvable
  backend pins — is fixed upstream; org consistency is what remains.)
- mojodoc dropped, the packaging and attribution files, and a CI that builds
  the package and consumes it rather than running upstream's test matrix.

## [0.10.1] - 2026-09-16

Tracks upstream **flare main** at `1e92aa3`, which is past the `v0.10.0` tag
but not yet tagged itself.

### Removed

The four pull requests 0.10.0 carried ahead of review have all merged
upstream, so this distribution stops carrying them — as 0.10.0 said it
should, the moment they landed. Upstream's reviewed versions replace the
copies here, and they differ in substance, not only in wording:

- [#14](https://github.com/ehsanmok/flare/pull/14) also bounds the TLS
  handshake and raises `Timeout` on a stalled TLS read. Two new wrapper
  exports carry it: `flare_ssl_connect_ex` classifies a handshake that
  expires, and `flare_ssl_read_blocking` splits the retryable case out of
  `SSL_read` without changing what end of stream means.
- [#15](https://github.com/ehsanmok/flare/pull/15) makes `_prebuf` a
  persistent carry-over. The version here delivered the first pipelined
  frame and dropped the rest, and the next `recv()` then blocked forever.
- [#16](https://github.com/ehsanmok/flare/pull/16) frees the offload context
  when `pthread_create` fails. The version here leaked a live socket per
  failed handshake, with nothing left to close it.
- [#11](https://github.com/ehsanmok/flare/pull/11) landed as-is, plus an
  upstream follow-up documenting the `Origin` cases an allow-list has to
  handle.

### Changed

- Upstream's 843-site deprecated-API migration and its generated per-area
  test aggregates come with the merge. `pixi run tests` is now
  `tools/run_test_aggregates.sh`; `pixi run tests-gen` regenerates
  `tests/_agg` after adding a test file.
- `threads-mojo` is pinned `>=0.5.2` rather than `>=0.5.1`. `_worker.mojo`
  calls `pin_current_to_cpu`, which no published version had until 0.5.2.

### Fixed

- `threads-mojo` is declared in `[dependencies]`, not only in `recipe.yaml`.
  The published package always had it; this environment never did, so every
  test that reached threading failed locally with "unable to locate module
  'threads'".
- `tests/http/test_server_drain.mojo` passes the `wheel` argument that the
  closed-connection timer-cancel fix added. That call site was missed, so the
  file had not compiled since.

### Still carried on top of upstream

- `flare/runtime/_thread.mojo` is an adapter over `threads.mojo` rather than
  its own pthread binding, so only one library binds each libc symbol and
  flare can be linked alongside the rest of the magmalake stack.
- `flare/runtime/_libc_time.mojo` calls `std.time.sleep` instead of binding
  `nanosleep`, for the same reason.
- The macOS shared-listener default, `json_mlake` / `mozz_mlake`, the dropped
  `mojodoc` dependency, and the packaging.

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
- **Package renamed to `flare_mlake`**; the installed module is still `flare`,
  so no consumer import changes. Only `context.name` moved — the build script
  stages the literal `flare/` directory as before.
- **`-include iterator` added to the simdjson wrapper compile.** `simdjson.h`
  uses `std::inserter` without including `<iterator>`; older standard libraries
  pulled it in transitively and current libc++ does not, so the build failed on
  macOS with `no member named 'inserter' in namespace 'std'`. A no-op where the
  transitive include still happens.
- **Attribution in the package metadata**: `license_file: LICENSE`, homepage,
  repository and documentation all point at upstream, and the description opens
  by stating this is a redistribution of Ehsan M. Kermani's work and that
  issues and pull requests belong upstream.
- Upstream's `README.md` preserved verbatim as `README.upstream.md`; the new
  `README.md` explains what this repository is and points at upstream.

### Verified

Built with `rattler-build` 0.76.0 for `osx-arm64` and installed into a clean
consumer project from a local channel: `from flare.net import SocketAddr`,
`flare.http` and `flare.grpc` all resolve **with no `-I` flag** and the binary
runs. The package carries 243 flare source files, 40 json source files and both
FFI shared libraries.

Note that `pixi` cannot resolve flare's own *source* dependencies (`json`,
`mozz`) on any current pixi, because those pin `pixi-build-rattler-build
==0.3.13`, which requires a `pixi-build-api-version` no longer published. That
blocks developing flare's test suite locally; it does not affect building or
consuming this package, which goes through `rattler-build` and the recipe.

### Not changed

- The module is still imported as `flare`, not `flare_mlake`. Only the *package*
  is renamed, so switching to an official flare package later is a one-line
  dependency change rather than a source-wide rename.
- `LICENSE` is upstream's, unmodified (MIT, © 2025 Ehsan M. Kermani).
- The `.so` filename in the recipe is left alone. It matches
  `flare.utils.dylib.find_flare_lib`, which looks for `.so` on every platform,
  and `dlopen` ignores the extension on macOS — the two are consistent and
  changing one without the other would break it.
