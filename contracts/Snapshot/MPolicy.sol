pragma solidity ^0.4.13;

// Mixin for the snapshot policy
contract MPolicy {

////////////////
// Internal abstract functions
////////////////

    // The snapshot Ids need to be monotonically increasing.
    // Whenever the snaspshot id changes, a new snapshot will
    // be created. As long as the same value is being returned,
    // this snapshot will be updated.
    //
    // Values passed to `hasValueAt` and `valuteAt` are required
    // to be strictly less than `mixinNextSnapshotId()`.
    function mNextSnapshotId()
        internal
        returns (uint256);

    function mFlagSnapshotModified()
        internal;
}
