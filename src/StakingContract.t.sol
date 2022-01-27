// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;

import "ds-test/test.sol";
import "./StakingContract.sol";

contract StakingContractTest is DSTest {
    StakingContract stakingContract;

    function setUp() public {
        stakingContract = new StakingContract();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
