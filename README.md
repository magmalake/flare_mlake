# flare_mlake

**This is not a new networking library. It is a packaged build of
[flare](https://github.com/ehsanmok/flare) by
[Ehsan M. Kermani](https://github.com/ehsanmok), redistributed so that
[magmalake](https://github.com/magmalake) can depend on it.**

Essentially all of the code here — TCP, UDP, TLS, DNS, HTTP/1.1, HTTP/2, HTTP/3,
QUIC, QPACK, WebSocket, gRPC, the reactor, io_uring, the SIMD parsers, the
conformance suite — is upstream's work. flare is a serious piece of engineering
and the credit for it belongs entirely to its author and contributors.

**If you are looking for the project, go upstream:
<https://github.com/ehsanmok/flare>.** Star it there, file issues there, send
pull requests there. This repository is a distribution channel, not a home for
development.

## Why this exists

Nothing publishes flare to a conda channel. `pixi` therefore cannot resolve it,
which is the single reason magmalake's `objectstore.mojo` is built on libcurl
instead — recorded in that repo as:

> Nothing in the Mojo package ecosystem gives this repo a TLS capable HTTP
> client: `floki`, `flare`, `lightbug-http` and `fire-http` all fail to resolve
> from conda ("No candidates were found").

flare already ships a perfectly good `recipe.yaml`. It has simply never been
built and published anywhere. This repository does that, and nothing more
interesting than that.

## What differs from upstream

As little as possible. The intent is that this stays a thin layer that could be
deleted at any time.

**Four features that are open pull requests upstream** — merged here only
because magmalake needs them now, and they are still awaiting review there:

| upstream PR | what it adds |
|---|---|
| [#11](https://github.com/ehsanmok/flare/pull/11) | expose the handshake `Origin` on `WsConnection` |
| [#14](https://github.com/ehsanmok/flare/pull/14) | bound body reads, not just connect |
| [#15](https://github.com/ehsanmok/flare/pull/15) | serve HTTP and WebSocket on one port |
| [#16](https://github.com/ehsanmok/flare/pull/16) | opt-in `ws_offload`, one thread per WebSocket |

Every one of these should land upstream and be dropped from here. They are
carried, not owned.

**Packaging changes** needed to publish and to consume from magmalake. These are
listed in [CHANGELOG.md](CHANGELOG.md) as they are made.

## The import name is still `flare`

The *package* is `flare_mlake`; the *module* is `flare`, unchanged:

```mojo
from flare.http import HttpClient
from flare.grpc import ...
```

This is deliberate. Renaming the module would touch every file, make every
future merge from upstream painful, and turn the eventual switch to an official
flare package into a source-wide rename. As it stands, that switch is a one-line
change to a dependency.

## This repository should not outlive its usefulness

The moment flare is published to a channel `pixi` can resolve — by its author, by
conda-forge, or by anyone else — magmalake should depend on that and this
repository should be archived. It exists to fill a packaging gap, and it stops
being justified the day that gap closes.

Upstream's own README is preserved verbatim as
[README.upstream.md](README.upstream.md).

## License

MIT, © 2025 Ehsan M. Kermani. See [LICENSE](LICENSE), which is unchanged from
upstream. The redistribution and the packaging deltas are offered under the same
terms.
