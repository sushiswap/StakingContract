// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;

import "ds-test/test.sol";
import "../libraries/PackedUint144.sol";

contract PackedUintTest is DSTest {

    using PackedUint144 for uint144;

    function testCountStoredUint24Values(uint24 a) public {
        uint144 packed = 0;
        assertEq(packed.countStoredUint24Values(), 0);
        if (a == 0) return;
        packed = packed.pushUint24Value(a);
        assertEq(packed.countStoredUint24Values(), 1);
        packed = packed.pushUint24Value(a);
        assertEq(packed.countStoredUint24Values(), 2);
        packed = packed.pushUint24Value(a);
        assertEq(packed.countStoredUint24Values(), 3);
        packed = packed.pushUint24Value(a);
        assertEq(packed.countStoredUint24Values(), 4);
        packed = packed.pushUint24Value(a);
        assertEq(packed.countStoredUint24Values(), 5);
        packed = packed.pushUint24Value(a);
        assertEq(packed.countStoredUint24Values(), 6);
    }

    function proveFail_pushUint24Value(uint144 a, uint24 b) public {
        while (a.countStoredUint24Values() < 7) {
            a = a.pushUint24Value(b);
        }
    }

    function testPushUint24Value(uint24 a, uint24 b, uint24 c, uint24 d, uint24 e, uint24 f) public {
        uint24 nil = 0;
        uint144 packed = 0;
        if (a == 0) return;
        packed = packed.pushUint24Value(a);
        assertEq(packed, uint144(bytes18(abi.encodePacked(nil, nil, nil, nil, nil, a))));
        if (b == 0) return;
        packed = packed.pushUint24Value(b);
        assertEq(packed, uint144(bytes18(abi.encodePacked(nil, nil, nil, nil, a, b))));
        if (c == 0) return;
        packed = packed.pushUint24Value(c);
        assertEq(packed, uint144(bytes18(abi.encodePacked(nil, nil, nil, a, b, c))));
        if (d == 0) return;
        packed = packed.pushUint24Value(d);
        assertEq(packed, uint144(bytes18(abi.encodePacked(nil, nil, a, b, c, d))));
        if (e == 0) return;
        packed = packed.pushUint24Value(e);
        assertEq(packed, uint144(bytes18(abi.encodePacked(nil, a, b, c, d, e))));
        if (f == 0) return;
        packed = packed.pushUint24Value(f);
        assertEq(packed, uint144(bytes18(abi.encodePacked(a, b, c, d, e, f))));
    }

    function testGetUint24ValueAt(uint24 a, uint24 b, uint24 c, uint24 d, uint24 e, uint24 f) public {
        uint144 packed = uint144(bytes18(abi.encodePacked(a, b, c, d, e, f)));
        assertEq(packed.getUint24ValueAt(6), uint24(0));
        assertEq(packed.getUint24ValueAt(5), a);
        assertEq(packed.getUint24ValueAt(4), b);
        assertEq(packed.getUint24ValueAt(3), c);
        assertEq(packed.getUint24ValueAt(2), d);
        assertEq(packed.getUint24ValueAt(1), e);
        assertEq(packed.getUint24ValueAt(0), f);
    }

    function testRemoveUint24ValueAt(uint24 a, uint24 b, uint24 c, uint24 d, uint24 e, uint24 f) public {
        uint144 packed = uint144(bytes18(abi.encodePacked(a, b, c, d, e, f)));
        uint24 nil = 0;
        assertEq(packed.removeUint24ValueAt(0), uint144(bytes18(abi.encodePacked(nil, a, b, c, d, e))));
        assertEq(packed.removeUint24ValueAt(1), uint144(bytes18(abi.encodePacked(nil, a, b, c, d, f))));
        assertEq(packed.removeUint24ValueAt(2), uint144(bytes18(abi.encodePacked(nil, a, b, c, e, f))));
        assertEq(packed.removeUint24ValueAt(3), uint144(bytes18(abi.encodePacked(nil, a, b, d, e, f))));
        assertEq(packed.removeUint24ValueAt(4), uint144(bytes18(abi.encodePacked(nil, a, c, d, e, f))));
        assertEq(packed.removeUint24ValueAt(5), uint144(bytes18(abi.encodePacked(nil, b, c, d, e, f))));
        assertEq(packed.removeUint24ValueAt(6), uint144(bytes18(abi.encodePacked(a, b, c, d, e, f))));
    }

}
