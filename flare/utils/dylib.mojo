"""Canonical FFI dylib path resolver shared across :mod:`flare`.

Consolidates the per-package FFI-lib finders: every package that
owned a C-side helper carried its own ``_find_flare_*_lib``
helper -- 7 callers, 4 lookalike implementations of the same
``CONDA_PREFIX`` / bare-checkout fallback search. Different
return values for
"library not present" (``"build/libflare_X.so"`` vs
``"libflare_X.so"``); identical search order otherwise.

This module is the single canonical home. Each call site that
opens a flare-bundled shared object goes through
:func:`find_flare_lib`; the bundled shim's name (the ``X`` in
``libflare_X.so``) is the only argument.

Library naming convention
-------------------------

flare bundles four FFI shims under ``$CONDA_PREFIX/lib/``:

* ``libflare_tls.so`` -- OpenSSL hooks (TLS handshake, AEAD,
  hkdf, hmac, sha1) plus the ``flare_read`` / ``flare_write``
  thin wrappers used by the io_uring reactor's hot path.
* ``libflare_zlib.so`` -- zlib + gzip + raw-deflate thin
  wrappers consumed by :mod:`flare.http.encoding` (HTTP
  ``Content-Encoding``) and :mod:`flare.ws.permessage_deflate`
  (WebSocket ``permessage-deflate``).
* ``libflare_brotli.so`` -- libbrotlienc + libbrotlidec
  consumed by :mod:`flare.http.encoding` for ``Content-Encoding:
  br``.
* ``libflare_fs.so`` -- ``access(2)`` + ``open(2)`` +
  ``read(2)`` + ``close(2)`` thin wrappers consumed by
  :mod:`flare.http.fs` (``FileServer`` static-file path).

Search order (used by every call site):
1. ``$FLARE_LIB_DIR/libflare_<name>.so`` -- when ``FLARE_LIB_DIR`` is
   an absolute path; for running outside pixi.
2. ``$CONDA_PREFIX/lib/libflare_<name>.so`` -- the canonical
   install location, populated by ``flare/<sub>/ffi/build.sh``
   on pixi activation.
3. ``<exe dir>/libflare_<name>.so`` and ``<exe dir>/../lib/...``,
   the running executable's directory (symlinks resolved) -- for a
   binary shipped next to its libraries.
4. The bare ``libflare_<name>.so``, which ``dlopen`` resolves on the
   binary's rpath (``mojo build`` records the lib directory of the
   environment it built in) and then the system library path. Never
   the working directory.

Steps 2-4 are :func:`flare.utils._dlopen.find_library`, the search
every magmalake tin that loads a library shares; each of 2 and 3 is
taken only when the file is there.
The path is built via ``String("") += prefix += literal``
rather than the ``prefix + literal`` concat operator. See the
:mod:`flare.tls.config` module docstring for the full rationale
(Mojo's concat can return a String whose buffer aliases another
``getenv`` + literal result, so two sequential
``CONDA_PREFIX + ...`` calls can clobber each other's bytes).

Public API
----------

``find_flare_lib(name: String) -> String``
    Resolves ``libflare_<name>.so`` in the order above. ``name`` is
    the bare suffix (``"tls"``, ``"zlib"``, ``"brotli"``, ``"fs"``).

``dl_sym[FT](lib: OwnedDLHandle, name: String) raises -> FT``
    Resolve a C-ABI function symbol. ``OwnedDLHandle.get_function``
    returns an origin-bound ``_DLCallable`` that cannot be called
    or stored the way plain function pointers used to be;
    ``get_symbol`` + address reinterpret is the replacement every
    FFI call site across :mod:`flare` now shares.
"""

from std.os import getenv
from std.ffi import OwnedDLHandle, _get_global

from ._dlopen import find_library, open_library
from std.memory import Layout, OptionalPointer, Pointer, alloc


def dl_sym[
    FT: TrivialRegisterPassable
](lib: OwnedDLHandle, name: String) raises -> FT:
    """Look up a C-ABI function symbol as a plain callable value.

    Replaces the ``lib.get_function[FT](name)`` idiom, whose return
    type (an origin-bound ``_DLCallable``) can no longer be invoked
    directly or stored across scopes.
    """
    var opt = lib.get_symbol[FT](name)
    if not opt:
        raise Error("flare: FFI symbol not found: " + name)
    var addr: Int = Int(opt.value())
    return Pointer(to=addr).unsafe_bitcast[FT]()[]


def _lib_in(dir: String, name: String) -> String:
    var out = String("")
    out += dir
    out += "/libflare_"
    out += name
    out += ".so"
    return out^


def find_flare_lib(name: String) -> String:
    """Return the path to ``libflare_<name>.so``.

    Search order:

    1. ``$FLARE_LIB_DIR/libflare_<name>.so``, when ``FLARE_LIB_DIR``
       is an absolute path. For running outside pixi, e.g. a bare
       checkout with ``FLARE_LIB_DIR=$PWD/build``.
    2. ``$CONDA_PREFIX/lib/libflare_<name>.so``, when ``CONDA_PREFIX``
       is absolute and the file is there: the install that
       ``flare/<sub>/ffi/build.sh`` populates on pixi activation.
    3. ``<exe dir>/libflare_<name>.so``, then
       ``<exe dir>/../lib/libflare_<name>.so``, when there.
    4. The bare file name, which ``dlopen`` looks up on the binary's
       rpath (the environment ``mojo build`` ran in, so a binary built
       under pixi runs from a plain shell), ``LD_LIBRARY_PATH`` /
       ``DYLD_LIBRARY_PATH`` and the system directories. It never looks
       in the working directory.

    The last step used to be ``build/libflare_<name>.so``, relative to
    the working directory. A flare program started with no
    ``CONDA_PREFIX`` from a directory someone else could write to (a
    shared ``/tmp``, a checked-out repository) loaded whatever
    ``build/libflare_tls.so`` it found there, and ran that code with the
    program's privileges.

    Args:
        name: The bare suffix, e.g. ``"tls"`` for
              ``libflare_tls.so``.

    Returns:
        Path string suitable for passing to ``OwnedDLHandle(path)``.
    """
    var dir = getenv("FLARE_LIB_DIR", "")
    if dir.startswith("/"):
        return _lib_in(dir, name)
    var file = String("")
    file += "libflare_"
    file += name
    file += ".so"
    return find_library(file)


def _pinned_init[
    name: StaticString
]() -> OptionalPointer[NoneType, UntrackedOrigin[mut=True]]:
    try:
        var lib = OwnedDLHandle(find_flare_lib(name))
        var cell = alloc(Layout[OwnedDLHandle](count=1)).unsafe_leak()
        cell.unsafe_write(lib^)
        return Pointer[NoneType, UntrackedOrigin[mut=True]](
            unsafe_from_address=Int(cell)
        )
    except:
        return OptionalPointer[NoneType, UntrackedOrigin[mut=True]]()


def _pinned_keep(p: OptionalPointer[NoneType, UntrackedOrigin[mut=True]]):
    pass


def pinned_flare_lib[
    name: StaticString
]() raises -> Pointer[OwnedDLHandle, MutUntrackedOrigin]:
    """The process-wide handle to ``libflare_<name>.so``, opened once.

    A per-call ``OwnedDLHandle`` costs a dlopen, symbol lookups and a
    dlclose under the loader lock every worker shares, and unmaps the
    library between calls when nothing else holds it. This one is opened
    on first use and never closed.

    Raises:
        Error: If the library cannot be loaded.
    """
    var p = _get_global[
        "flare_dylib_" + name, _pinned_init[name], _pinned_keep
    ]()
    if not p:
        # Open it once more for the reason: `open_library` names every
        # place it looked and says to set CONDA_PREFIX.
        var file = String("libflare_") + String(name) + ".so"
        var dir = getenv("FLARE_LIB_DIR", "")
        if dir.startswith("/"):
            _ = OwnedDLHandle(_lib_in(dir, name))
        _ = open_library("flare", file)
        raise Error("flare: cannot load " + file)
    return Pointer[OwnedDLHandle, MutUntrackedOrigin](
        unsafe_from_address=Int(p.value())
    )
