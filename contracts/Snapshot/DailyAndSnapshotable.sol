pragma solidity ^0.4.13;

import './MPolicy.sol';
import './ISnapshotable.sol';

contract DailyAndSnapshotable is
    MPolicy,
    ISnapshotable
{

    // Floor[2**128 / 1 days]
    uint256 MAX_TIMESTAMP = 3938453320844195178974243141571391;

    uint256 nextSnapshotId;
    bool nextSnapshotModified;

    function SnapshotDailyHybrid() {
        uint256 dayBase = 2**128 * (block.timestamp / 1 days);
        nextSnapshotId = dayBase + 1;
        nextSnapshotModified = false;
    }

    function snapshotAt(uint256 timestamp)
        public
        constant
        returns (uint256)
    {
        require(timestamp < MAX_TIMESTAMP);

        uint256 dayBase = 2**128 * (timestamp / 1 days);
        return dayBase;
    }

    function createSnapshot()
        public
        returns (uint256)
    {
        uint256 dayBase = 2**128 * (block.timestamp / 1 days);

        // New day has started, create snapshot for midnight
        if (dayBase > nextSnapshotId) {
            nextSnapshotId = dayBase + 1;
            nextSnapshotModified = false;

            SnapshotCreated(dayBase);
            return dayBase;
        }

        // Same day, no modifications
        if (!nextSnapshotModified) {
            return nextSnapshotId - 1;
        }

        // Increment the snapshot counter
        uint256 snapshotId = nextSnapshotId;
        nextSnapshotId += 1;
        nextSnapshotModified = false;

        // Log and return
        SnapshotCreated(snapshotId);
        return snapshotId;
    }

    function mNextSnapshotId()
        internal
        returns (uint256)
    {
        uint256 dayBase = 2**128 * (block.timestamp / 1 days);

        // New day has started
        if (dayBase > nextSnapshotId) {
            nextSnapshotId = dayBase + 1;
            nextSnapshotModified = false;

            SnapshotCreated(dayBase);
            return nextSnapshotId;
        }

        // Within same day
        return nextSnapshotId;
    }

    function mFlagSnapshotModified()
        internal
    {
        if (!nextSnapshotModified) {
            nextSnapshotModified = true;
        }
    }
}
