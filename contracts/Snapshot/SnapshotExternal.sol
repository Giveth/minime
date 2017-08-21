pragma solidity ^0.4.13;

import './MixinSnapshotPolicy.sol';
import './ISnapshotPolicy.sol';

contract SnapshotExternal is MixinSnapshotPolicy {

    ISnapshotPolicy public externalSnapshotPolicy;

    function SnapshotExternal(ISnapshotPolicy externalPolicy) {
        externalSnapshotPolicy = externalPolicy;
    }

    function setExternalSnapshotId()
         public
    {
    }

    function mixinNextSnapshotId()
        internal
        returns (uint256)
    {
        return externalSnapshotPolicy.nextSnapshotId();
    }

    function mixinFlagSnapshotModified()
        internal
    {
        return externalSnapshotPolicy.flagSnapshotModified();
    }
}
