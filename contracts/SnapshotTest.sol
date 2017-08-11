pragma solidity ^0.4.13;

import './Snapshot.sol';

contract SnapshotTest is Snapshot {

    Values[] myNumber;

    function SnapshotTest()
        Snapshot(0)
    {
    }

    function create()
        external
        returns (uint256)
    {
        return Snapshot.createSnapshot();
    }

    function get()
        external
        returns (uint256)
    {
        return getValue(myNumber, 0);
    }

    function get(uint256 snapshot)
        external
        returns (uint256)
    {
        return getValueAt(myNumber, snapshot, 0);
    }

    function set(uint256 value)
        external
    {
        return setValue(myNumber, value);
    }

}
