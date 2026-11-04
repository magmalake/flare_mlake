"""Tests for :func:`flare.utils.dylib.find_flare_lib`'s search order."""

from std.os import getenv, setenv, unsetenv
from std.os.path import dirname, exists
from std.testing import assert_equal, assert_false, assert_true

from flare.utils._dlopen import executable_dir
from flare.utils.dylib import find_flare_lib, pinned_flare_lib


def test_never_resolves_against_the_working_directory() raises:
    """With no CONDA_PREFIX the resolver returned
    ``build/libflare_<name>.so``, which dlopen reads relative to the
    working directory: a program started in a directory someone else
    could write to loaded their library."""
    var saved_prefix = getenv("CONDA_PREFIX", "")
    var saved_dir = getenv("FLARE_LIB_DIR", "")
    _ = unsetenv("CONDA_PREFIX")
    _ = unsetenv("FLARE_LIB_DIR")
    var bare = find_flare_lib("tls")
    _ = setenv("FLARE_LIB_DIR", "relative/dir")
    var relative = find_flare_lib("tls")
    _ = setenv("FLARE_LIB_DIR", "/opt/flare/lib")
    var explicit = find_flare_lib("tls")
    _ = setenv("CONDA_PREFIX", saved_prefix)
    if saved_dir != "":
        _ = setenv("FLARE_LIB_DIR", saved_dir)
    else:
        _ = unsetenv("FLARE_LIB_DIR")
    # Without CONDA_PREFIX: next to the executable or in its ../lib when
    # there (under `mojo run` that is the environment's own lib), else the
    # bare name for the dynamic linker. Never a relative path.
    var exe = executable_dir()
    if exists(exe + "/libflare_tls.so"):
        assert_equal(bare, exe + "/libflare_tls.so")
    elif exists(dirname(exe) + "/lib/libflare_tls.so"):
        assert_equal(bare, dirname(exe) + "/lib/libflare_tls.so")
    else:
        assert_equal(bare, "libflare_tls.so")
    assert_true(
        bare.startswith("/") or not ("/" in bare), "relative path: " + bare
    )
    assert_false(relative.startswith("relative/"), "relative FLARE_LIB_DIR")
    assert_equal(explicit, "/opt/flare/lib/libflare_tls.so")


def test_missing_library_says_to_set_conda_prefix() raises:
    """A shim that isn't anywhere raises an Error that names it and says to
    set CONDA_PREFIX, rather than a bare dlopen message."""
    try:
        _ = pinned_flare_lib["magmalake_missing"]()
    except e:
        var msg = String(e)
        assert_true("libflare_magmalake_missing.so" in msg, msg)
        assert_true("CONDA_PREFIX" in msg, msg)
        return
    raise Error("pinned_flare_lib opened a library that doesn't exist")


def main() raises:
    test_never_resolves_against_the_working_directory()
    test_missing_library_says_to_set_conda_prefix()
    print("test_dylib: 2 passed")
