# MiniMeToken

A MiniMeToken is a standard ERC20 token with some extra functionality:

### The token is clonable

Any body can create a new token with an initial distribution of cloned tokens identical to the original token. At some specific block.

To create a child token, the next function is defined:

     function createChildToken(
            string _childTokenName,
            uint8 _childDecimalUnits,
            string _childTokenSymbol
            uint _snapshotBlock,            // if block is not already mined, it will teke the current block
            bool _isConstant
        ) returns(address)

Once the child token is created, it acts as a completely independent token.

### Balances history is registered and available

The contract maintains a history of all the distribution changes of the token. Two calls are introduced to know the totalSupply and the balance of any address at any block in the past.

    function totalSupplyAt(uint _blockNumber) constant returns(uint)

    function balanceOfAt(address _holder, uint _blockNumber) constant returns (uint)

### Optional token owner

The owner of the contract can generate/destroy/transfer tokens at its own discretion. Of course, the owner can be a regular account, another contract that rules the contract or just the address 0x0 if this functionality is not wanted.

As an example, a Token Creation contract can be the owner of the Token Contract and at the end of the token creation period, the ownership can be transfered to the 0x0 address.

To create and destroy tokens, this two functions are introduced:

    function generateTokens(address _holder, uint _value) onlyOwner

    function destroyTokens(address _holder, uint _value) onlyOwner

### Owner of the token can freeze the transfers.

Tokens can be created with the constant flag set on, and the owner can also toggle this flag. When a token is flagged with this flag, no transfers, generations and destroys are allowed.

    function setConstant(bool _isConstant) onlyOwner


## Applications

Some of the applications that child tokens can be used for are:

1. a ballot that is burned when you vote.
2. a discount ticked that is redeemed when you use it.
3. a token of a "spinoff" DAO.
4. a token that can be used to give explicit support to an action or a campaign.
5. lots of other applications.

And all that maintaining always the original token.
