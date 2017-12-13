const TestRPC = require('ethereumjs-testrpc');
const assert = require('chai').assert;
const Web3 = require('web3')

const MiniMeToken = require('../js/minimetoken');
const MiniMeTokenState = require('../js/minimetokenstate');

const deployToken = require('../js/deploy_contracts').deploy;
const tokenOptions = require('../js/config').token_defaults;

describe('MiniMeToken Deployment test', () => {
    let deploymentOptions = { testnet: ''};
    let testrpc;
    let web3;
    let accounts;
    let tokenFactoryAddress;
    let tokenAddress;
    let miniMeToken;
    let miniMeTokenState;

    before(async () => {
        testrpc = TestRPC.server({
            gasLimit: 5800000,
            total_accounts: 10
        });
        // Listen on localhost:8546
        testrpc.listen(8546, '127.0.0.1');

        web3 = new Web3('http://localhost:8546');
        accounts = await web3.eth.getAccounts();
        deploymentOptions.testnet = 'http://127.0.0.1:8546';
    });

    after(() => {
        testrpc.close();
    });

    it('Deploys contract to test net', async () => {
        [tokenFactoryAddress, tokenAddress] = await deployToken(tokenOptions, deploymentOptions);
        assert.isDefined(tokenFactoryAddress);
        assert.isTrue(tokenFactoryAddress !== '');
        assert.isDefined(tokenAddress);
        assert.isTrue(tokenAddress !== '');
    });

    it('Checks the deployed contract', async () => {
        miniMeToken = new MiniMeToken(web3, tokenAddress);
        miniMeTokenState = new MiniMeTokenState(miniMeToken);
        const state = await miniMeTokenState.getState();
        assert.equal(state.name, tokenOptions.tokenName);
        assert.equal(state.controller, accounts[0]);
    });

    it('Generates token and adds it to the controllers balance', async () => {
        await miniMeToken.generateTokens(10);
        const state = await miniMeTokenState.getState();
        assert.equal(state.totalSupply, 10);
        assert.equal(state.balances[accounts[0]], 10);
    });
});
