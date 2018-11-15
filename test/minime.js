// Force web3 1.0.0
const Web3 = require("web3");
const web3 = new Web3(Web3.givenProvider);
const BigNumber = require('bignumber.js');

var MiniMeTokenFactory = artifacts.require("MiniMeTokenFactory");
var MiniMeToken = artifacts.require("MiniMeToken");

contract('MiniMeTokenFactory', async (accounts) => {

  let factory;
  let token;
  let tokenClone;
  let blocks = [];

  it('should deploy all the contracts', async () => {
    factory = await MiniMeTokenFactory.new();
    assert.ok(factory.address);
    token = await MiniMeToken.new(
      factory.address,
      0,
      0,
      'MiniMe Test Token',
      18,
      'MMT',
      true);
    assert.ok(token.address);
  });

  it('Should generate tokens for address 1', async () => {
    blocks.push(await web3.eth.getBlockNumber());
    await token.generateTokens(accounts[1], 10);
    assert.equal(await token.totalSupply(), 10);
    assert.equal(await token.balanceOf(accounts[1]), 10);
    blocks.push(await web3.eth.getBlockNumber());
  });

  it('Should transfer tokens from address 1 to address 2', async () => {
    await token.transfer(accounts[2], 2, {from: accounts[1], gas: 200000});
    blocks.push(await web3.eth.getBlockNumber());
    assert.equal(await token.totalSupply(), 10);
    assert.equal(await token.balanceOf(accounts[1]), 8);
    assert.equal(await token.balanceOf(accounts[2]), 2);
    assert.equal(await token.balanceOfAt(accounts[1], blocks[1]), 10)
  });

  it('Should allow and transfer tokens from address 2 to address 1 allowed to 3', async () => {
    await token.approve(accounts[3], 2, {from: accounts[2]});
    assert.equal(await token.allowance(accounts[2], accounts[3]), 2);

    blocks.push(await web3.eth.getBlockNumber());
    await token.transferFrom(accounts[2], accounts[1], 1, {from: accounts[3]});

    assert.equal(await token.allowance(accounts[2], accounts[3]), 1);
    assert.equal(await token.totalSupply(), 10);
    assert.equal(await token.balanceOf(accounts[1]), 9);
    assert.equal(await token.balanceOf(accounts[2]), 1);

    assert.equal(await token.balanceOfAt(accounts[1], blocks[2]), 8);
    assert.equal(await token.balanceOfAt(accounts[2], blocks[2]), 2);
    assert.equal(await token.balanceOfAt(accounts[1], blocks[1]), 10);
    assert.equal(await token.balanceOfAt(accounts[2], blocks[1]), 0);
    assert.equal(await token.balanceOfAt(accounts[1], blocks[0]), 0);
    assert.equal(await token.balanceOfAt(accounts[2], blocks[0]), 0);
    assert.equal(await token.balanceOfAt(accounts[1], 0), 0);
    assert.equal(await token.balanceOfAt(accounts[2], 0), 0);
  });

  it('Should Destroy 3 tokens from 1 and 1 from 2', async () => {
    await token.destroyTokens(accounts[1], 3, {from: accounts[0], gas: 200000});
    blocks.push(await web3.eth.getBlockNumber());
    assert.equal(await token.totalSupply(), 7);
    assert.equal(await token.balanceOf(accounts[1]), 6);
  });

  it('Should Create the clone token', async () => {
    let tokenCloneTx = await token.createCloneToken(
      'Clone Token 1',
      18,
      'MMTc',
      0,
      true);

    let addr = tokenCloneTx.logs[0].args._cloneToken;
    tokenClone = MiniMeToken.at(addr);
    blocks.push(await web3.eth.getBlockNumber());

    assert.equal(await tokenClone.parentToken(), token.address);
    assert.equal(await tokenClone.parentSnapShotBlock(), blocks[5]);
    assert.equal(await tokenClone.totalSupply(), 7);
    assert.equal(await tokenClone.balanceOf(accounts[1]), 6);
    assert.equal(await tokenClone.totalSupplyAt(blocks[4]), 7);
    assert.equal(await tokenClone.balanceOfAt(accounts[2], blocks[4]), 1);
  });

  it('Should mine one block to take effect clone', async () => {
    await token.transfer(accounts[1], 1, { from: accounts[1] });
  });

  it('Should move tokens in the clone token from 2 to 3', async () => {
    await tokenClone.transfer(accounts[2], 4, {from: accounts[1]});
    blocks.push(await web3.eth.getBlockNumber());
    assert.equal(await tokenClone.totalSupply(), 7);
    console.log(await tokenClone.balanceOf(accounts[1]));
    assert.equal((await tokenClone.balanceOf(accounts[1])).toNumber(), 2);
    assert.equal(await tokenClone.balanceOf(accounts[2]), 5);

    assert.equal(await tokenClone.balanceOfAt(accounts[1], blocks[5]), 6);
    assert.equal(await tokenClone.balanceOfAt(accounts[2], blocks[5]), 1);
    assert.equal(await tokenClone.balanceOfAt(accounts[1], blocks[5]), 6);
    assert.equal(await tokenClone.balanceOfAt(accounts[2], blocks[5]), 1);
    assert.equal(await tokenClone.balanceOfAt(accounts[1], blocks[4]), 6);
    assert.equal(await tokenClone.balanceOfAt(accounts[2], blocks[4]), 1);

    assert.equal(await tokenClone.totalSupplyAt(blocks[5]), 7);
    assert.equal(await tokenClone.totalSupplyAt(blocks[4]), 7);
  });

  it('Should create tokens in the child token', async () => {
    await tokenClone.generateTokens(accounts[1], 10, {from: accounts[0], gas: 300000});
    assert.equal(await tokenClone.totalSupply(), 17);
    assert.equal((await tokenClone.balanceOf(accounts[1])).toNumber(), 12);
    assert.equal(await tokenClone.balanceOf(accounts[2]), 5);
  });
});
