pragma solidity ^0.4.13;

import './MixinSnapshotPolicy.sol';

contract SnapshotBlocks is MixinSnapshotPolicy {

    function mixinNextSnapshotId()
        internal
        returns (uint256)
    {
        return block.number;
    }

    function mixinFlagSnapshotModified()
        internal
    {
    }
}
