# MiniMeToken

A MiniMeToken is a standard ERC20 token with some extra functionality:

### The token is easy to clone!

Anybody can create a new clone token of any token using this contract with an initial distribution identical to the original token at a specified block. The address calling the `createCloneToken` function will become the token controller and the token's default settings can be specified in the function call.

    function createCloneToken(
        string _cloneTokenName,
        uint8 _cloneDecimalUnits,
        string _cloneTokenSymbol,
        uint _snapshotBlock,
        bool _isConstant
        ) returns(address) {

Once the clone token is created, it acts as a completely independent token.

### Balance history is registered and available to be queried

All MiniMe Tokens maintain a history of the balance changes that occur during each block. Two calls are introduced to read the totalSupply and the balance of any address at any block in the past.

    function totalSupplyAt(uint _blockNumber) constant returns(uint)

    function balanceOfAt(address _holder, uint _blockNumber) constant returns (uint)

### Optional token controller

The controller of the contract can generate/destroy/transfer tokens at its own discretion. The controller can be a regular account, but the intention is for the controller to be another contract that imposes transparent rules on the token's issuance and functionality. The Token Controller is not required for the MiniMe token to function, if there is no reason to  generate/destroy/transfer tokens, the token controller can be set to 0x0 and this functionality will be disabled.

For example, a Token Creation contract can be set as the controller of the MiniMe Token and at the end of the token creation period, the controller can be transfered to the 0x0 address, to guarentee that no new tokens will be created.

To create and destroy tokens, these two functions are introduced:

    function generateTokens(address _holder, uint _value) onlyOwner

    function destroyTokens(address _holder, uint _value) onlyOwner

### The Token's Controller can freeze transfers.

 If isConstant == True, tokens cannot be transfered, however they can still be created or destroyed by the controller. The controller can also toggle this flag. 

    function setConstant(bool _isConstant) onlyOwner  // Allows tokens to be transfered if false or frozen if true


## Applications

If this Token contract is used as the base token, then it can easily generate clones of itself at any given block number, which allows for incredibly powerful functionality. Some of the applications that the MiniMe token contract can be used for are:

1. Generating a voting token that is burned when you vote.
2. Generating a discount ticket that is redeemed when you use it.
3. Generating a token for a "spinoff" DAO.
4. Generating a token that can be used to give explicit support to an action or a campaign.
5. Generating a token to enable the token holders to collect daily, monthly or yearly payments.
6. Generating a token to limit participation in a specific token sale or similar event to holders of a specific token.
7. Generating token that allows a central party complete control to transfer/generate/destroy tokens at will. 
8. Lots of other applications including all the applications the standard ERC 20 token can be used for.

All these applications and more are enabled by the MiniMe Token Contract by anyone without effecting the parent token nor requiring any action from the parent token holders. 
