
//File: ./contracts/IERC223bTokenFallback.sol
pragma solidity ^0.4.18;

interface IERC223bTokenFallback {
    function tokenFallback(address _from, address _to, uint _value, bytes _data) public;
}
