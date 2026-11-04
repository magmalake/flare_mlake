# Flare's fcntl, linked beside the declaration dista and orca use.
#
# Two different declarations of one C function in a program don't compile
# on Linux ("failed to legalize operation 'pop.external_call'"), so this
# file only builds while flare declares fcntl as dista does: two fixed
# arguments, then the variadic one.

from std.ffi import c_int, external_call
from std.testing import TestSuite, assert_equal, assert_true

from flare.net._libc import _fcntl2
from flare.net._libc_cloexec import F_GETFD, FD_CLOEXEC, _set_cloexec

comptime F_GETFL: c_int = 3


def dista_fcntl(fd: c_int, cmd: c_int, arg: c_int) -> c_int:
    """The declaration in dista.socket."""
    return external_call["fcntl", c_int, num_fixed_args=2](fd, cmd, arg)


def test_both_declarations_link_and_agree() raises:
    var fds = Array[c_int, 2](fill=-1)
    assert_equal(external_call["pipe", c_int](fds.unsafe_ptr()), 0)
    assert_equal(_fcntl2(fds[0], F_GETFL, 0), dista_fcntl(fds[0], F_GETFL, 0))
    _set_cloexec(fds[0])
    assert_true((dista_fcntl(fds[0], F_GETFD, 0) & FD_CLOEXEC) != 0)
    _ = external_call["close", c_int](fds[0])
    _ = external_call["close", c_int](fds[1])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
