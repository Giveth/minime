pragma solidity ^0.4.13;

contract Snapshot {

////////////////
// Types
////////////////

    /// @dev `Checkpoint` is the structure that attaches a block number to a
    ///  given value, the block number attached is the one that last changed the
    ///  value
    struct Values {

        // `fromBlock` is the block number that the value was generated from
        uint256 snapshot;

        // `value` is the amount of tokens at a specific block number
        uint256 value;
    }

////////////////
// State
////////////////

    uint256 internal nextSnapshot;

    bool internal nextSnapshotModified;

////////////////
// Events
////////////////

    event SnapshotCreated(uint256 snapshot);

////////////////
// Constructor
////////////////

    function Snapshot(uint256 snapshotStart)
        internal
    {
        require(snapshotStart < 2**256 - 1);

        // We can start at non-zero counter so the snapshots can
        // continue from some other contract's snapshots. This is
        // useful for forking.
        nextSnapshot = snapshotStart + 1;
        nextSnapshotModified = false;
    }

////////////////
// Public functions
////////////////

    function createSnapshot()
        public
        returns (uint256)
    {
        require(nextSnapshot < 2**256 - 1);

        // If no modifications have been made, the previous snapshot
        // is identical to the current one. We can return the previous
        // entry.
        // TODO: Is this optimization worth it? It only avoids one
        // storage counter increment.
        if (!nextSnapshotModified) {
            return nextSnapshot - 1;
        }

        uint256 snapshot = nextSnapshot;
        nextSnapshot += 1;
        SnapshotCreated(snapshot);
        nextSnapshotModified = false;
        return snapshot;
    }

////////////////
// Internal functions
////////////////

    function hasValue(
        Values[] storage values
    )
        internal
        constant
        returns (bool)
    {
        return values.length > 0;
    }

    function hasValueAt(
        Values[] storage values,
        uint _snapshot
    )
        internal
        constant
        returns (bool)
    {
        require(_snapshot < nextSnapshot);
        return values.length > 0 && values[0].snapshot <= _snapshot;
    }

    function getValue(
        Values[] storage values,
        uint _defaultValue
    )
        internal
        constant
        returns (uint)
    {
        if (values.length == 0) {
            return _defaultValue;
        } else {
            uint last = values.length - 1;
            return values[last].value;
        }
    }

    /// @dev `getValueAt` retrieves the number of tokens at a given block number
    /// @param values The history of values being queried
    /// @param _snapshot The block number to retrieve the value at
    /// @return The number of tokens being queried
    function getValueAt(
        Values[] storage values,
        uint _snapshot,
        uint _defaultValue
    )
        internal
        constant
        returns (uint)
    {
        require(_snapshot < nextSnapshot);

        // Empty value
        if (values.length == 0) {
            return _defaultValue;
        }

        // Shortcut for the out of bounds snapshots
        uint last = values.length - 1;
        uint lastSnapshot = values[last].snapshot;
        if (_snapshot >= lastSnapshot) {
            return values[last].value;
        }
        uint firstSnapshot = values[0].snapshot;
        if (_snapshot < firstSnapshot) {
            return _defaultValue;
        }

        // Binary search of the value in the array
        uint min = 0;
        uint max = last;
        while (max > min) {
            uint mid = (max + min + 1) / 2;
            if (values[mid].snapshot <= _snapshot) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return values[min].value;
    }

    /// @dev `setValue` used to update the `balances` map and the
    ///  `totalSupplyHistory`
    /// @param values The history of data being updated
    /// @param _value The new number of tokens
    function setValue(
        Values[] storage values,
        uint256 _value
    )
        internal
    {
        // TODO: simplify or break into smaller functions

        // Always create a new entry if there currently is no value
        bool empty = values.length == 0;
        if (empty) {
            // Create a new entry
            values.push(Values({
                snapshot: nextSnapshot,
                value: _value
            }));

            // Flag next snapshot as modified
            if (!nextSnapshotModified) {
                nextSnapshotModified = true;
            }
            return;
        }

        uint last = values.length - 1;
        bool frozen = values[last].snapshot < nextSnapshot;
        if (frozen) {

            // Do nothing if the value was not modified
            bool unmodified = values[last].value != _value;
            if (unmodified) {
                return;
            }

            // Create new entry
            values.push(Values({
                snapshot: nextSnapshot,
                value: _value
            }));

            // Flag next snapshot as modified
            if (!nextSnapshotModified) {
                nextSnapshotModified = true;
            }

        } else { // We are updating the nextSnapshot

            bool unmodifiedd = last > 0 && values[last - 1].value == _value;
            if (unmodifiedd) {
                // Remove nextSnapshot entry
                delete values[last];
                values.length--;
                return;
            }

            // Overwrite next snapshot entry
            values[last].value = _value;
        }
    }
}
