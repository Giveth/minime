pragma solidity ^0.4.13;

import './MixinSnapshotPolicy.sol';
import './ISnapshotPolicy.sol';

// Consumes MixinSnapshotPolicy and turns it into ISnapshotPolicy
contract SnapshotExternalize is
    ISnapshotPolicy,
    MixinSnapshotPolicy
{
    function nextSnapshotId()
        public
        returns (uint256)
    {
        return mixinNextSnapshotId();
    }

    function flagSnapshotModified()
        public
    {
        return mixinFlagSnapshotModified();
    }
}
