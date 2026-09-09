"""Threads for flare, on top of `threads.mojo`.

## Why this is no longer its own pthread binding

Upstream flare binds `pthread_create`, `pthread_join`, `pthread_self` and
`pthread_setaffinity_np` itself, and so does `threads.mojo`. The signatures are
ABI-identical but spelled differently — `UnsafePointer` on one side, `Pointer`
on the other, behind the same machine pointer — and Mojo declares an extern
*per signature*. A binary that needs both therefore refuses to lower:

    error: existing function with conflicting signature
    error: failed to legalize operation 'pop.external_call' … "pthread_create"

That is not hypothetical. magmalake serves Arrow Flight from flare while
reading Iceberg tables, and Iceberg's scan parallelism is `threads.mojo`; the
two could not be linked into one program at all.

Two libraries binding the same libc symbol is normal and will only become more
common, so the fix is to stop having two. `threads.mojo` owns the binding and
flare's threading is a thin adapter over it. The public surface is unchanged —
`ThreadHandle` with `spawn` / `join` / `detach` / `pin_to_cpu`, plus
`current_thread_id` and `num_cpus` — so flare's own call sites are untouched.

`_OpaquePtr` is now `threads.ffi.OpaquePtr`, i.e. `Pointer[UInt8, …]` rather
than `UnsafePointer[UInt8, …]`. The same pointer at runtime; keeping flare's
own name means the call sites still read as they did.

This is a delta the fork carries deliberately, and it is the kind worth
sending upstream: it removes a duplicate binding rather than adding a feature.

This file is *internal* — used by `flare.runtime.scheduler` and its neighbours.
"""

from threads.ffi import OpaquePtr
from threads.thread import ThreadHandle as _ThreadsHandle
from threads.thread import current_thread_id as _threads_current_id
from threads.thread import num_cpus as _threads_num_cpus

comptime _OpaquePtr = OpaquePtr
"""The opaque `void *` a thread body receives and returns.

Aliased to `threads.ffi.OpaquePtr` so exactly one declaration of the pthread
entry-point shape exists in any linked binary.
"""

comptime _StartFn = def (_OpaquePtr) thin -> _OpaquePtr
"""A thread body: thin (non-capturing) and non-raising.

pthread has no exception channel, so a body that fails has to convert the
failure into something the caller can read back out of its argument.
"""


def _null_ptr() -> _OpaquePtr:
    """A NULL `void *`, for entry points that take no argument.

    Built from a runtime zero: the pointer types reject a comptime-literal
    address of 0, but pthread genuinely wants a C NULL here.
    """
    var null_addr = 0
    return _OpaquePtr(unsafe_from_address=null_addr)


struct ThreadHandle(Movable):
    """One joinable OS thread.

    Move-only, like the handle it wraps: moving transfers the obligation to
    `join` or `detach`. Copying would leave two owners each believing they
    must join, and the second would be joining a thread id that is no longer
    live.
    """

    var _inner: _ThreadsHandle

    def __init__(out self, var inner: _ThreadsHandle):
        self._inner = inner^

    @staticmethod
    def spawn[start: _StartFn](arg: _OpaquePtr) raises -> ThreadHandle:
        """Spawn a thread running `start(arg)`.

        Parameters:
            start: Entry function; thin and non-raising.

        Args:
            arg: Passed straight through to `start`. It must outlive the
                thread — nothing here keeps it alive.

        Returns:
            A joinable handle.

        Raises:
            Error: If the thread could not be created.
        """
        return ThreadHandle(_ThreadsHandle.spawn[start](arg))

    def join(mut self) raises:
        """Wait for the thread to finish.

        Idempotent: joining an already-joined handle returns immediately
        rather than failing against a dead thread id.
        """
        self._inner.join()

    def detach(mut self) raises:
        """Give up the right to join; the thread releases itself on exit."""
        self._inner.detach()

    def is_joinable(self) -> Bool:
        """Whether `join` would still wait on a live thread."""
        return self._inner.is_joinable()

    def pin_to_cpu(self, cpu: Int) raises:
        """Pin this thread to one core.

        A real pin on Linux via `pthread_setaffinity_np`; a no-op on macOS,
        which has no hard equivalent — Mach's `THREAD_AFFINITY_POLICY` is a
        hint, and the platform's own topology picker is good enough here.
        """
        self._inner.pin_to_cpu(cpu)


def current_thread_id() -> UInt64:
    """An opaque id for the calling thread, for logging and assertions."""
    return _threads_current_id()


def num_cpus() -> Int:
    """Online cores, as a default worker count."""
    return _threads_num_cpus()
