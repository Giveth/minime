pragma solidity ^0.4.13;

import './MixinSnapshotId.sol';

contract SnapshotBlocks is MixinSnapshotId {

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
