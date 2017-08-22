pragma solidity ^0.4.13;

import './MPolicy.sol';

contract Daily is MPolicy {

    function snapshotAt(uint256 timestamp)
        public
        constant
        returns (uint256)
    {
        // Round down to the start of the day (00:00 UTC)
        timestamp -= timestamp % 1 days;

        return timestamp;
    }

    function mNextSnapshotId()
        internal
        returns (uint256)
    {
        // Take the current time in UTC
        uint256 timestamp = block.timestamp;

        // Round down to the start of the day (00:00 UTC)
        timestamp -= timestamp % 1 days;

        return timestamp;
    }

    function mFlagSnapshotModified()
        internal
    {
    }
}
