"""Flare declares libc's socket calls as dista and Mosaad-M/tcp do.

Mojo allows one signature per C symbol in a program, so a binary importing
flare and dista (morca is one) compiles only if both declare `send`, `recv`,
`connect`, `accept`, `close`, `setsockopt`, `getsockopt`, `poll`,
`getaddrinfo`, `waitpid` and `_exit` alike. This file declares them as
dista.socket does, in the same program as flare's own wrappers, and calls
both, so it builds only while the declarations agree.
"""

from std.ffi import c_int, c_uint, external_call
from std.memory import stack_allocation
from std.sys.info import CompilationTarget
from std.testing import TestSuite, assert_equal, assert_true

from flare.net import SocketAddr
from flare.net._libc import (
    _close,
    _connect,
    _getaddrinfo,
    _getsockopt,
    _poll,
    _recv,
    _send,
    _setsockopt,
)
from flare.tcp import TcpListener, TcpStream
from flare.utils import exit, fork, waitpid


# ── The declarations in dista.socket ─────────────────────────────────────────


def _dista_send(fd: Int32, buf_addr: Int, length: Int, flags: Int32) -> Int:
    return external_call["send", Int](fd, buf_addr, length, flags)


def _dista_recv(fd: Int32, buf_addr: Int, length: Int, flags: Int32) -> Int:
    return external_call["recv", Int](fd, buf_addr, length, flags)


def _dista_connect(fd: Int32, addr: Int, addrlen: Int32) -> Int32:
    return external_call["connect", Int32](fd, addr, addrlen)


def _dista_close(fd: Int32) -> Int32:
    return external_call["close", Int32](fd)


def _dista_setsockopt(
    fd: Int32, level: Int32, name: Int32, value: Int, length: Int32
) -> Int32:
    return external_call["setsockopt", Int32](fd, level, name, value, length)


def _dista_getsockopt(
    fd: Int32, level: Int32, name: Int32, value: Int, length_addr: Int
) -> Int32:
    return external_call["getsockopt", Int32](
        fd, level, name, value, length_addr
    )


def _dista_poll(fds_addr: Int, nfds: Int, timeout_ms: Int32) -> Int32:
    return external_call["poll", Int32](fds_addr, nfds, timeout_ms)


def _dista_accept(fd: c_int) -> c_int:
    return external_call["accept", c_int](fd, Int(0), Int(0))


def _dista_getaddrinfo(host: String, hints: Int, slot: Int) -> Int32:
    var name = host
    var rc = external_call["getaddrinfo", Int32](
        Int(name.as_c_string_span().ptr()), Int(0), hints, slot
    )
    _ = name^
    return rc


def _dista_waitpid(pid: Int) -> Int:
    var status = stack_allocation[1, c_int]()
    status[] = 0
    _ = external_call["waitpid", c_int](c_int(pid), status, c_int(0))
    return Int(status[])


def _dista_exit(code: Int):
    external_call["_exit", NoneType](c_int(code))


def _sol_socket() -> c_int:
    return 0xFFFF if CompilationTarget.is_macos() else 1


def _so_reuseaddr() -> c_int:
    return 0x0004 if CompilationTarget.is_macos() else 2


def _so_error() -> c_int:
    return 0x1007 if CompilationTarget.is_macos() else 4


# ── Tests ────────────────────────────────────────────────────────────────────


def test_flare_and_dista_declarations_link_together() raises:
    var l = TcpListener.bind(SocketAddr.localhost(0))
    var c = TcpStream.connect(SocketAddr.localhost(l.local_addr().port))
    var s = l.accept()
    var cfd = c._socket.fd
    var sfd = s._socket.fd

    # flare sends, dista receives; then the other way round.
    var one = List[UInt8](length=1, fill=7)
    assert_equal(Int(_send(cfd, one.unsafe_ptr(), 1, 0)), 1)
    assert_equal(one[0], 7)  # keeps `one` alive across the send
    var pfd = List[Int32](length=2, fill=0)
    pfd[0] = sfd
    pfd[1] = 1  # events = POLLIN, revents = 0
    assert_equal(_dista_poll(Int(pfd.unsafe_ptr()), 1, Int32(5000)), 1)
    assert_equal(pfd[0], sfd)  # keeps `pfd` alive across the poll
    var got = List[UInt8](length=1, fill=0)
    assert_equal(_dista_recv(sfd, Int(got.unsafe_ptr()), 1, Int32(0)), 1)
    assert_equal(got[0], 7)
    assert_equal(_dista_send(sfd, Int(got.unsafe_ptr()), 1, Int32(0)), 1)
    assert_equal(got[0], 7)
    pfd[0] = cfd
    pfd[1] = 1
    assert_equal(
        Int(_poll(pfd.unsafe_ptr().unsafe_bitcast[UInt8](), c_uint(1), 5000)), 1
    )
    var back = List[UInt8](length=1, fill=0)
    assert_equal(Int(_recv(cfd, back.unsafe_ptr(), 1, 0)), 1)
    assert_equal(back[0], 7)

    # setsockopt / getsockopt, each way.
    var v = List[c_int](length=1, fill=1)
    assert_equal(
        Int(
            _setsockopt(
                cfd,
                _sol_socket(),
                _so_reuseaddr(),
                v.unsafe_ptr().unsafe_bitcast[UInt8](),
                c_uint(4),
            )
        ),
        0,
    )
    assert_equal(
        _dista_setsockopt(
            cfd, _sol_socket(), _so_reuseaddr(), Int(v.unsafe_ptr()), 4
        ),
        0,
    )
    v[0] = 99
    var vlen = List[c_uint](length=1, fill=4)
    assert_equal(
        Int(
            _getsockopt(
                cfd,
                _sol_socket(),
                _so_error(),
                v.unsafe_ptr().unsafe_bitcast[UInt8](),
                vlen.unsafe_ptr(),
            )
        ),
        0,
    )
    assert_equal(v[0], 0)
    v[0] = 99
    var dlen = List[Int32](length=1, fill=4)
    assert_equal(
        _dista_getsockopt(
            cfd,
            _sol_socket(),
            _so_error(),
            Int(v.unsafe_ptr()),
            Int(dlen.unsafe_ptr()),
        ),
        0,
    )
    assert_equal(v[0], 0)
    assert_equal(vlen[0], 4)  # keeps both length cells alive
    assert_equal(dlen[0], 4)

    # The rest fail on a bad fd, through either declaration.
    var addr = List[UInt8](length=16, fill=0)
    assert_equal(Int(_connect(-1, addr.unsafe_ptr(), c_uint(16))), -1)
    assert_equal(_dista_connect(-1, Int(addr.unsafe_ptr()), Int32(16)), -1)
    assert_equal(addr[0], 0)
    assert_equal(Int(_dista_accept(-1)), -1)
    assert_equal(Int(_close(-1)), -1)
    assert_equal(_dista_close(-1), -1)
    # Both ends stay open until here: a value dies after its last use, which
    # can be before a call that was passed its `fd` runs.
    c.close()
    s.close()
    l.close()


def test_getaddrinfo_both_declarations() raises:
    var hints = List[UInt8](length=48, fill=0)
    var slot = List[Int](length=1, fill=0)
    var rc = _getaddrinfo(
        "127.0.0.1",
        hints.unsafe_ptr(),
        slot.unsafe_ptr().unsafe_bitcast[UInt8](),
    )
    assert_equal(Int(rc), 0)
    assert_true(slot[0] != 0)
    _ = external_call["freeaddrinfo", NoneType](
        Pointer[NoneType, MutUntrackedOrigin](unsafe_from_address=slot[0])
    )
    slot[0] = 0
    rc = _dista_getaddrinfo(
        "127.0.0.1", Int(hints.unsafe_ptr()), Int(slot.unsafe_ptr())
    )
    assert_equal(Int(rc), 0)
    assert_true(slot[0] != 0)
    _ = external_call["freeaddrinfo", NoneType](
        Pointer[NoneType, MutUntrackedOrigin](unsafe_from_address=slot[0])
    )
    assert_equal(hints[0], 0)  # keeps `hints` alive across the calls


def test_fork_exit_waitpid_both_declarations() raises:
    # flare's exit, reaped through dista's waitpid.
    var pid = fork()
    if pid == 0:
        exit(3)
    assert_true(pid > 0)
    var status = _dista_waitpid(pid)
    assert_equal((status >> 8) & 0xFF, 3)  # WEXITSTATUS
    # dista's _exit, reaped through flare's waitpid.
    pid = fork()
    if pid == 0:
        _dista_exit(0)
    assert_true(pid > 0)
    waitpid(pid)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
