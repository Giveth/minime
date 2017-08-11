pragma solidity ^0.4.13;

contract Snapshot {

    /// @dev `Checkpoint` is the structure that attaches a block number to a
    ///  given value, the block number attached is the one that last changed the
    ///  value
    struct Values {

        // `fromBlock` is the block number that the value was generated from
        uint256 snapshot;

        // `value` is the amount of tokens at a specific block number
        uint256 value;
    }

    uint256 internal nextSnapshot;

    event SnapshotCreated(uint256 snapshot);

    function Snapshot()
        internal
    {
        nextSnapshot = 0;
    }

    function createSnapshot()
        internal
        returns (uint256)
    {
        uint256 snapshot = nextSnapshot;
        nextSnapshot += 1;
        SnapshotCreated(snapshot);
        return snapshot;
    }

    function getValue(
        Values[] storage values,
        uint _defaultValue
    )
        internal
        constant
        returns (uint)
    {
        return getValueAt(values, nextSnapshot, _defaultValue);
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
        if (values.length == 0) {
            return _defaultValue;
        }

        // Shortcut for the actual value
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
        uint last = values.length - 1;
        bool empty = values.length == 0;
        bool frozen = !empty && values[last].snapshot < nextSnapshot;
        if (empty || frozen) {
            // Create a new entry
            values.push(Values({
                snapshot: nextSnapshot,
                value: _value
            }));
       } else {
           // Overwrite existing entry
           values[last].value = _value;
       }
    }

}
