const TestRPC = require('ethereumjs-testrpc');
const Web3 = require('web3');
const chai = require('chai');

const MiniMeToken = require('./minimetoken');
const MiniMeTokenFactory = require('./minimetokenfactory');

const tokenDefaults = require('./config').token_defaults;
const deploymentDefaults = require('./config').deployment_defaults;

/*
 * Async function used for deploying contracts.
 * On resolve returns an array of the contract address for TokenFactory and Token respectively.
 * tokenOptions: Options related to token deployment.
 * deploymentOptions: Testnet address.
 */
async function deploy(tokenOptions, deploymentOptions) {
    deploymentOptions = Object.assign(deploymentDefaults, deploymentOptions);
    tokenOptions = Object.assign(tokenDefaults, tokenOptions);

    // If testing locally please start the testrpc first.
    // For Mist enabled browsers Web3.givenProvider will point to the current Ether network in use.
    let web3 = new Web3(Web3.givenProvider || deploymentOptions.testnet);

    const is_connected = await web3.eth.net.isListening();

    if(is_connected) {
        const tokenFactory = await MiniMeTokenFactory.new(web3);
        const miniMeToken = await MiniMeToken.new(web3, tokenFactory.$address,
            tokenOptions.parentToken, tokenOptions.parentSnapShotBlock,
            tokenOptions.tokenName, tokenOptions.decimalUnits,
            tokenOptions.tokenSymbol, tokenOptions.transfersEnabled
        );

        return [tokenFactory.$address, miniMeToken.$address];
    }
}

exports.deploy = deploy;
