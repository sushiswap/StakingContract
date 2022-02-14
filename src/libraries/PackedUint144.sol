pragma solidity >=0.8.0;

library PackedUint144 {

    uint256 private constant MAX_UINT24 = type(uint24).max;
    uint256 private constant MAX_UINT48 = type(uint48).max;
    uint256 private constant MAX_UINT72 = type(uint72).max;
    uint256 private constant MAX_UINT96 = type(uint96).max;
    uint256 private constant MAX_UINT120 = type(uint120).max;
    uint256 private constant MAX_UINT144 = type(uint144).max;

    error NonZero();
    error FullyPacked();

    function pushUint24Value(uint144 packedUint144, uint24 value) internal pure returns (uint144) {
        if (value == 0) revert NonZero(); // Not strictly necessairy for our use-case since value (incentiveId) can't be 0.
        if (packedUint144 > MAX_UINT120) revert FullyPacked();
        return (packedUint144 << 24) + value;
    }

    function countStoredUint24Values(uint144 packedUint144) internal pure returns (uint256) {
        if (packedUint144 == 0) return 0;
        if (packedUint144 <= MAX_UINT24) return 1;
        if (packedUint144 <= MAX_UINT48) return 2;
        if (packedUint144 <= MAX_UINT72) return 3;
        if (packedUint144 <= MAX_UINT96) return 4;
        if (packedUint144 <= MAX_UINT120) return 5;
        return 6;
    }

    function getUint24ValueAt(uint144 packedUint144, uint256 i) internal pure returns (uint24) {
        return uint24(packedUint144 >> (i * 24));
    }

    function removeUint24ValueAt(uint144 packedUint144, uint256 i) internal pure returns (uint144) {
        if (i > 5) return packedUint144;
        uint256 rightMask = MAX_UINT144 >> (24 * (6 - i));
        uint256 leftMask = (~rightMask) << 24;
        uint256 left = packedUint144 & leftMask;
        uint256 right = packedUint144 & rightMask;
        return uint144((left >> 24) | right);
    }

}
