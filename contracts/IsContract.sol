pragma solidity ^0.4.13;

contract IsContract {

    function IsContract() internal {}

    /// @dev Internal function to determine if an address is a contract
    /// @param _addr The address being queried
    /// @return True if `_addr` is a contract
    function isContract(address _addr)
        internal
        constant
        returns (bool)
    {
        uint size;
        if (_addr == 0) {
            return false; // TODO: Is this necessary?
        }
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
