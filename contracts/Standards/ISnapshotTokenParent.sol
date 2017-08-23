pragma solidity ^0.4.13;

contract ISnapshotTokenParent {

    /// @notice Total amount of tokens at a specific `_snapshot`.
    /// @param _snapshot The block number when the totalSupply is queried
    /// @return The total amount of tokens at `_snapshot`
    function totalSupplyAt(uint _snapshot)
        public
        constant
        returns(uint);

    /// @dev Queries the balance of `_owner` at a specific `_snapshot`
    /// @param _owner The address from which the balance will be retrieved
    /// @param _snapshot The block number when the balance is queried
    /// @return The balance at `_snapshot`
    function balanceOfAt(address _owner, uint _snapshot)
        public
        constant
        returns (uint);
}
