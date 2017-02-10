"use strict";

var Web3 = require('web3');
// create an instance of web3 using the HTTP provider.
// NOTE in mist web3 is already available, so check first if its available before instantiating
var web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));

var BigNumber = require('bignumber.js');

var eth = web3.eth;
var async = require('async');

var MiniMeToken = require('./dist/minimetoken.js');

var gcb = function(err, res) {
    if (err) {
        console.log("ERROR: "+err);
    } else {
        console.log(JSON.stringify(res,null,2));
    }
}

var minimeToken;

function deployExample(cb) {
    cb = cb || gcb;
    async.series([
        function(cb) {
            MiniMeToken.deploy(web3, {
                tokenName: "MiniMe Test Token",
                decimalUnits: 18,
                tokenSymbol: "MMT",
            }, function(err, _minimeToken) {
                if (err) return err;
                minimeToken = _minimeToken;
                console.log("Minime Token: " + minimeToken.contract.address);
                cb();
            });
        },
        function(cb) {
            minimeToken.generateTokens({
                owner: eth.accounts[ 1 ],
                amount: 10,
                from: eth.accounts[ 0 ],
            },cb);
        },
    ], cb);

}
