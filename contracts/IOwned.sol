pragma solidity ^0.4.13;


/// @dev `Owned` is a base level contract that assigns an `owner` that can be
///  later changed
contract IOwned {

    function owner()
        public
        returns (address);

    /// @notice `owner` can step down and assign some other address to this role
    /// @param _newOwner The address of the new owner. 0x0 can be used to create
    ///  an unowned neutral vault, however that cannot be undone
    function changeOwner(address _newOwner)
        public;

}
