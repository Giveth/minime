pragma solidity ^0.4.13;

import './MixinSnapshotPolicy.sol';
import './ISnapshotable.sol';

contract SnapshotAll is MixinSnapshotPolicy, ISnapshotable {

    uint256 snapshotId;
    bool nextSnapshotModified;

    function SnapshotOndemand(uint256 start)
        internal
    {
        snapshotId = start;
    }

    function createSnapshot()
        public
        returns (uint256)
    {
        return snapshotId;
    }

    function mixinNextSnapshotId()
        internal
        returns (uint256)
    {
        return snapshotId + 1;
    }

    function mixinFlagSnapshotModified()
        internal
    {
        SnapshotCreated(snapshotId);
        snapshotId += 1;
    }
}
