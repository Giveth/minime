pragma solidity ^0.4.13;

import './MixinSnapshotPolicy.sol';
import './ISnapshotPolicy.sol';

contract SnapshotExternal is MixinSnapshotPolicy {

    ISnapshotPolicy public snapshotPolicy;

    event SnapshotPolicyChanged(
        ISnapshotPolicy oldPolicy,
        ISnapshotPolicy newPolicy
    );

    function SnapshotExternal(ISnapshotPolicy initialPolicy) {
        snapshotPolicy = initialPolicy;
    }

    function setSnapshotPolicy(ISnapshotPolicy newPolicy)
         public
    {
        if (snapshotPolicy == newPolicy) {
            return;
        }

        ISnapshotPolicy oldPolicy = snapshotPolicy;
        snapshotPolicy = newPolicy;

        SnapshotPolicyChanged(oldPolicy, newPolicy);
    }

    function mixinNextSnapshotId()
        internal
        returns (uint256)
    {
        return snapshotPolicy.nextSnapshotId();
    }

    function mixinFlagSnapshotModified()
        internal
    {
        return snapshotPolicy.flagSnapshotModified();
    }
}
