#!/usr/bin/env bash
# Install the freshly built package into a throwaway project and compile
# against it with no `-I` flag, the way a real consumer would.
#
# The `-I`-free part is the point: it proves the recipe staged the module
# where Mojo looks for it ($CONDA_PREFIX/lib/mojo), rather than the build
# merely having produced a file.
set -euo pipefail

# Only the platform this runner just built is present in the local channel, so
# the throwaway project must declare exactly that one. Declaring both makes
# pixi solve for both and fail on whichever it has no packages for.
case "$(uname -s)/$(uname -m)" in
  Linux/x86_64)  PLATFORM=linux-64  ;;
  Darwin/arm64)  PLATFORM=osx-arm64 ;;
  Darwin/x86_64) PLATFORM=osx-64    ;;
  *) echo "unsupported runner: $(uname -s)/$(uname -m)" >&2; exit 1 ;;
esac
echo "consuming on $PLATFORM"

CHANNEL="$(cd ./channel && pwd)"
WORK="$(mktemp -d)"
cd "$WORK"

cat > pixi.toml <<TOML
[workspace]
name = "consume-smoke"
# Git dependencies are source dependencies, which pixi gates behind this.
preview = ["pixi-build"]
channels = ["file://$CHANNEL", "https://conda.modular.com/max-nightly", "conda-forge"]
platforms = ["$PLATFORM"]

[dependencies]
mojo = "==1.0.0"
flare_mlake = "*"
# flare imports `threads` since its threading became an adapter over
# threads.mojo, and the recipe takes threads-mojo as a run requirement. It is
# a pixi source tin rather than a package on any channel, so a consumer
# declares it as a git dependency — which is also what 'pixi shelf add' writes.
threads-mojo = { git = "https://github.com/magmalake/threads.mojo.git", branch = "main" }
# flare_mlake depends on json_mlake rather than vendoring json's source, so a
# consumer needs it too. Declared here as a git source dependency, which is
# exactly how mojoshelf tins are consumed ('pixi shelf add' writes the same
# shape, pinned at the published revision).
json_mlake = { git = "https://github.com/magmalake/json_mlake.git", branch = "main" }
TOML

cat > smoke.mojo <<'MOJO'
from flare.net import SocketAddr
from flare.http import HttpClient
from flare.grpc import *

def main():
    print("flare_mlake: module 'flare' resolved from the package with no -I")
MOJO

pixi install
pixi run mojo build smoke.mojo -o ./smoke
./smoke
