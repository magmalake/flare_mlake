# Flare's mmap and munmap, linked beside the declarations memory-region (and
# so every Iceberg pipeline) uses.
#
# Two different declarations of one C function in a program don't compile
# on Linux ("failed to legalize operation 'pop.external_call'"), so this
# file only builds while flare declares them as memory-region does: every
# argument an Int but the offset, an Int64, returning an Int (mmap) or an
# Int32 (munmap).

from std.ffi import external_call
from std.sys.info import CompilationTarget
from std.testing import TestSuite, assert_equal, assert_true

from flare.runtime.io_uring_driver import libc_mmap, libc_munmap

comptime PROT_READ_WRITE = 3
comptime MAP_PRIVATE = 2
comptime MAP_ANON = 0x1000 if CompilationTarget.is_macos() else 0x20


def region_map(size: Int) -> Int:
    """The declaration in memory_region.ffi (anonymous here)."""
    return external_call["mmap", Int](
        0, size, PROT_READ_WRITE, MAP_PRIVATE | MAP_ANON, -1, Int64(0)
    )


def region_unmap(addr: Int, size: Int) -> Int32:
    return external_call["munmap", Int32](addr, size)


def test_both_declarations_link_and_agree() raises:
    var size = 1 << 16
    var a = region_map(size)
    assert_true(a != -1 and a != 0)
    var p = libc_mmap(size, PROT_READ_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0)
    assert_true(Int(p) != -1 and Int(p) != 0)
    p[] = 42
    assert_equal(Int(p[]), 42)
    assert_equal(libc_munmap(p, size), 0)
    assert_equal(Int(region_unmap(a, size)), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
