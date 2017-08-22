pragma solidity ^0.4.13;


contract TokenInfo {

    string public name;                //The Token's name: e.g. DigixDAO Tokens
    uint8 public decimals;             //Number of decimals of the smallest unit
    string public symbol;              //An identifier: e.g. REP
    string public version;             //An arbitrary versioning scheme

    /// @notice Constructor to create a MiniMeToken
    /// @param _tokenName Name of the new token
    /// @param _decimalUnits Number of decimals of the new token
    /// @param _tokenSymbol Token Symbol for the new token
    function TokenInfo(
        string _tokenName,
        uint8 _decimalUnits,
        string _tokenSymbol,
        string _version
    ) {
        name = _tokenName;                                 // Set the name
        decimals = _decimalUnits;                          // Set the decimals
        symbol = _tokenSymbol;                             // Set the symbol
        version = _version;
    }
}
