/* eslint-env mocha */
/* eslint-disable no-await-in-loop */
const TestRPC = require('ethereumjs-testrpc');
const Web3 = require('web3');
const chai = require('chai');

const MiniMeToken = require('../index.js').MiniMeToken;
const MiniMeTokenFactory = require('../index.js').MiniMeTokenFactory;
const MiniMeTokenState = require('../index.js').MiniMeTokenState;

const assert = chai.assert;
const { utils } = Web3;

const verbose = false;

const log = (S) => {
  if (verbose) {
    console.log(S);
  }
};

// b[0]  ->  0, 0, 0, 0
// b[1]  ->  0,10, 0, 0
// b[2]  ->  0, 8, 2, 0
// b[3]  ->  0, 9, 1, 0
// b[4]  ->  0, 6, 1, 0
//  Clone token
// b[5]  ->  0, 6, 1, 0
// b[6]  ->  0, 2, 5. 0

describe('MiniMeToken test', () => {
  let testrpc;
  let web3;
  let accounts;
  let miniMeToken;
  let miniMeTokenState;
  let miniMeTokenClone;
  let miniMeTokenCloneState;
  const b = [];

  before(async () => {
    testrpc = TestRPC.server({
      ws: true,
      gasLimit: 5800000,
      total_accounts: 10,
    });

    testrpc.listen(8546, '127.0.0.1');

    web3 = new Web3('ws://localhost:8546');
    accounts = await web3.eth.getAccounts();
  });

  after((done) => {
    testrpc.close();
    done();
  });

  it('should deploy all the contracts', async () => {
    const tokenFactory = await MiniMeTokenFactory.new(web3);
    miniMeToken = await MiniMeToken.new(web3,
      tokenFactory.$address,
      0,
      0,
      'MiniMe Test Token',
      18,
      'MMT',
      true);
    assert.ok(miniMeToken.$address);
    miniMeTokenState = new MiniMeTokenState(miniMeToken);
  }).timeout(20000);

  it('Should generate tokens for address 1', async () => {
    b[0] = await web3.eth.getBlockNumber();
    log(`b[0]-> ${b[0]}`);

    await miniMeToken.generateTokens(accounts[1], 10);
    const st = await miniMeTokenState.getState();
    assert.equal(st.totalSupply, 10);
    assert.equal(st.balances[accounts[1]], 10);
    b[1] = await web3.eth.getBlockNumber();
  }).timeout(6000);

  it('Should transfer tokens from address 1 to address 2', async () => {
    await miniMeToken.transfer(accounts[2], 2, { from: accounts[1], gas: 200000 });
    b[2] = await web3.eth.getBlockNumber();
    log(`b[2]->  ${b[3]}`);
    const st = await miniMeTokenState.getState();
    assert.equal(st.totalSupply, 10);
    assert.equal(st.balances[accounts[1]], 8);
    assert.equal(st.balances[accounts[2]], 2);

    const balance = await miniMeToken.balanceOfAt(accounts[1], b[1]);
    assert.equal(balance, 10);
  }).timeout(6000);

  it('Should allow and transfer tokens from address 2 to address 1 allowed to 3', async () => {
    await miniMeToken.approve(accounts[3], 2, { from: accounts[2] });
    const allowed = await miniMeToken.allowance(accounts[2], accounts[3]);
    assert.equal(allowed, 2);

    await miniMeToken.transferFrom(accounts[2], accounts[1], 1, { from: accounts[3] });

    const allowed2 = await miniMeToken.allowance(accounts[2], accounts[3]);
    assert.equal(allowed2, 1);

    b[3] = await web3.eth.getBlockNumber();
    log(`b[3]->  ${b[3]}`);
    const st = await miniMeTokenState.getState();
    assert.equal(st.totalSupply, 10);
    assert.equal(st.balances[accounts[1]], 9);
    assert.equal(st.balances[accounts[2]], 1);

    let balance;

    balance = await miniMeToken.balanceOfAt(accounts[1], b[2]);
    assert.equal(balance, 8);
    balance = await miniMeToken.balanceOfAt(accounts[2], b[2]);
    assert.equal(balance, 2);
    balance = await miniMeToken.balanceOfAt(accounts[1], b[1]);
    assert.equal(balance, 10);
    balance = await miniMeToken.balanceOfAt(accounts[2], b[1]);
    assert.equal(balance, 0);
    balance = await miniMeToken.balanceOfAt(accounts[1], b[0]);
    assert.equal(balance, 0);
    balance = await miniMeToken.balanceOfAt(accounts[2], b[0]);
    assert.equal(balance, 0);
    balance = await miniMeToken.balanceOfAt(accounts[1], 0);
    assert.equal(balance, 0);
    balance = await miniMeToken.balanceOfAt(accounts[2], 0);
    assert.equal(balance, 0);
  });

  it('Should Destroy 3 tokens from 1 and 1 from 2', async () => {
    await miniMeToken.destroyTokens(accounts[1], 3, { from: accounts[0], gas: 200000 });
    b[4] = await web3.eth.getBlockNumber();
    log(`b[4]->  ${b[4]}`);
    const st = await miniMeTokenState.getState();
    assert.equal(st.totalSupply, 7);
    assert.equal(st.balances[accounts[1]], 6);
  });

  it('Should Create the clone token', async () => {
    const miniMeTokenCloneTx = await miniMeToken.createCloneToken(
      'Clone Token 1',
      18,
      'MMTc',
      0,
      true);

    let addr = miniMeTokenCloneTx.events.NewCloneToken.raw.topics[1];
    addr = `0x${addr.slice(26)}`;
    addr = utils.toChecksumAddress(addr);
    miniMeTokenClone = new MiniMeToken(web3, addr);

    miniMeTokenCloneState = new MiniMeTokenState(miniMeTokenClone);

    b[5] = await web3.eth.getBlockNumber();
    log(`b[5]->  ${b[5]}`);
    const st = await miniMeTokenCloneState.getState();

    assert.equal(st.parentToken, miniMeToken.$address);
    assert.equal(st.parentSnapShotBlock, b[5]);
    assert.equal(st.totalSupply, 7);
    assert.equal(st.balances[accounts[1]], 6);

    const totalSupply = await miniMeTokenClone.totalSupplyAt(b[4]);

    assert.equal(totalSupply, 7);

    const balance = await miniMeTokenClone.balanceOfAt(accounts[2], b[4]);
    assert.equal(balance, 1);
  }).timeout(6000);

  it('Should mine one block to take effect clone', async () => {
    await miniMeToken.transfer(accounts[1], 1, { from: accounts[1] });
  });

  it('Should move tokens in the clone token from 2 to 3', async () => {
    await miniMeTokenClone.transfer(accounts[2], 4, { from: accounts[1] });
    b[6] = await web3.eth.getBlockNumber();
    log(`b[6]->  ${b[6]}`);

    const st = await miniMeTokenCloneState.getState();
    assert.equal(st.totalSupply, 7);
    assert.equal(st.balances[accounts[1]], 2);
    assert.equal(st.balances[accounts[2]], 5);

    let balance;

    balance = await miniMeToken.balanceOfAt(accounts[1], b[5]);
    assert.equal(balance, 6);
    balance = await miniMeToken.balanceOfAt(accounts[2], b[5]);
    assert.equal(balance, 1);
    balance = await miniMeTokenClone.balanceOfAt(accounts[1], b[5]);
    assert.equal(balance, 6);
    balance = await miniMeTokenClone.balanceOfAt(accounts[2], b[5]);
    assert.equal(balance, 1);
    balance = await miniMeTokenClone.balanceOfAt(accounts[1], b[4]);
    assert.equal(balance, 6);
    balance = await miniMeTokenClone.balanceOfAt(accounts[2], b[4]);
    assert.equal(balance, 1);

    let totalSupply;
    totalSupply = await miniMeTokenClone.totalSupplyAt(b[5]);
    assert.equal(totalSupply, 7);
    totalSupply = await miniMeTokenClone.totalSupplyAt(b[4]);
    assert.equal(totalSupply, 7);
  }).timeout(6000);

  it('Should create tokens in the child token', async () => {
    await miniMeTokenClone.generateTokens(accounts[1], 10, { from: accounts[0], gas: 300000 });
    const st = await miniMeTokenCloneState.getState();
    assert.equal(st.totalSupply, 17);
    assert.equal(st.balances[accounts[1]], 12);
    assert.equal(st.balances[accounts[2]], 5);
  });
});
