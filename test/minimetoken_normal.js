/*jslint node: true */
/*global describe, it, before, beforeEach, after, afterEach */
"use strict";



var miniMeTokenHelper = require('../js/minimetoken_helper.js');
var ethConnector = require('ethconnector');
var BigNumber = require('bignumber.js');


var assert = require("assert"); // node.js core module
var async = require('async');
var _ = require('lodash');

var verbose = false;


// b[0]  ->  0, 0, 0, 0
// b[1]  ->  0,10, 0, 0
// b[2]  ->  0, 8, 2, 0
// b[3]  ->  0, 9, 1, 0
// b[4]  ->  0, 6, 1, 0
//  Child token
// b[5]  ->  0, 6, 1, 0
// b[6]  ->  0, 2, 5. 0



describe('MiniMeToken test', function(){
    var miniMeToken;
    var miniMeTokenChild;
    var b = [];

    before(function(done) {
        ethConnector.init('testrpc' ,done);
//        ethConnector.init('rpc', done);
    });
    it('should deploy all the contracts ', function(done){
        this.timeout(200000000);
        var now = Math.floor(new Date().getTime() /1000);

        miniMeTokenHelper.deploy({
            tokenName: "MiniMe Test Token",
            decimalUnits: 18,
            tokenSymbol: "MMT",
        }, function(err, _miniMeToken) {
            assert.ifError(err);
            assert.ok(_miniMeToken.address);
            miniMeToken = _miniMeToken;
            done();
        });
    });
    it('Should generate tokens for address 1', function(done) {
        this.timeout(2000);
        async.series([
            function(cb) {
                ethConnector.web3.eth.getBlockNumber(function (err, _blockNumber) {
                    assert.ifError(err);
                    b[0] = _blockNumber;
                    log("b[0]->"+b[0]);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.generateTokens(ethConnector.accounts[1], ethConnector.web3.toWei(10), {
                    from: ethConnector.accounts[0],
                    gas: 200000},
                    function(err) {
                        assert.ifError(err);
                        cb();
                    }
                );
            },
            function(cb) {
                miniMeToken.totalSupply(function(err, _totalSupply) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_totalSupply), 10);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOf(ethConnector.accounts[1], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 10);
                    cb();
                });
            },
            function(cb) {
                ethConnector.web3.eth.getBlockNumber(function (err, _blockNumber) {
                    assert.ifError(err);
                    b[1] = _blockNumber;
                    log("b[1]->"+b[1]);
                    cb();
                });
            }
        ],function(err) {
            done();
        });
    });
    it('Should transfer tokens from address 1 to address 2', function(done) {
        this.timeout(2000);
        async.series([

            function(cb) {
                miniMeToken.transfer(ethConnector.accounts[2], ethConnector.web3.toWei(2), {
                    from: ethConnector.accounts[1],
                    gas: 200000},
                    function(err) {
                        assert.ifError(err);
                        cb();
                    }
                );
            },
            function(cb) {
                ethConnector.web3.eth.getBlockNumber(function (err, _blockNumber) {
                    assert.ifError(err);
                    b[2] = _blockNumber;
                    log("b[2]->"+b[2]);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.totalSupply(function(err, _totalSupply) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_totalSupply), 10);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOf(ethConnector.accounts[1], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 8);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOf(ethConnector.accounts[2], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 2);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOfAt(ethConnector.accounts[1], b[1], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance).toNumber(), 10);
                    cb();
                });
            },
        ],function(err) {
            done();
        });
    });
    it('Should allow and transfer tokens from address 2 to address 1 allowed to 3', function(done) {
        async.series([
            function(cb) {
                miniMeToken.approve(ethConnector.accounts[3], ethConnector.web3.toWei(2), {
                    from: ethConnector.accounts[2],
                    gas: 200000},
                    function(err) {
                        assert.ifError(err);
                        cb();
                    }
                );
            },
            function(cb) {
                miniMeToken.allowance(ethConnector.accounts[2], ethConnector.accounts[3], function(err, _allowed) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_allowed), 2);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.transferFrom(ethConnector.accounts[2], ethConnector.accounts[1], ethConnector.web3.toWei(1), {
                    from: ethConnector.accounts[3],
                    gas: 200000},
                    function(err) {
                        assert.ifError(err);
                        cb();
                    }
                );
            },
            function(cb) {
                miniMeToken.allowance(ethConnector.accounts[2], ethConnector.accounts[3], function(err, _allowed) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_allowed), 1);
                    cb();
                });
            },
            function(cb) {
                ethConnector.web3.eth.getBlockNumber(function (err, _blockNumber) {
                    assert.ifError(err);
                    b[3] = _blockNumber;
                    log("b[3]->"+b[3]);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOf(ethConnector.accounts[1], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 9);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOf(ethConnector.accounts[2], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 1);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOfAt(ethConnector.accounts[1], b[2], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 8);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOfAt(ethConnector.accounts[2], b[2], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 2);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOfAt(ethConnector.accounts[1], b[1], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 10);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOfAt(ethConnector.accounts[2], b[1], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 0);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOfAt(ethConnector.accounts[1], b[0], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 0);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOfAt(ethConnector.accounts[2], b[0], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 0);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOfAt(ethConnector.accounts[1], 0, function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 0);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOfAt(ethConnector.accounts[2], 0, function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 0);
                    cb();
                });
            },
        ],function(err) {
            done();
        });
    });

    it('Should Destroy 3 tokens from 1 and 1 from 2', function(done) {
        async.series([
            function(cb) {
                miniMeToken.destroyTokens(ethConnector.accounts[1], ethConnector.web3.toWei(3), {
                    from: ethConnector.accounts[0],
                    gas: 200000},
                    function(err) {
                        assert.ifError(err);
                        cb();
                    }
                );
            },
            function(cb) {
                ethConnector.web3.eth.getBlockNumber(function (err, _blockNumber) {
                    assert.ifError(err);
                    b[4] = _blockNumber;
                    log("b[4]->"+b[4]);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.totalSupply(function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 7);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOf(ethConnector.accounts[1], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 6);
                    cb();
                });
            },
        ],function(err) {
            done();
        });
    });

    it('Should Create the child token', function(done) {
        this.timeout(200000000);
        async.series([
            function(cb) {
                miniMeToken.createChildToken(
                    "Child Token 1",
                    18,
                    "MMTc",
                    Number.MAX_SAFE_INTEGER,
                    false,
                    {
                        from: ethConnector.accounts[3],
                        gas: 4700000
                    },
                    function(err, txHash) {
                        assert.ifError(err);
                        ethConnector.web3.eth.getTransactionReceipt(txHash, function(err, res) {
                            var childTokenAddr = ethConnector.web3.toBigNumber(res.logs[0].topics[1]).toString(16);
                            while (childTokenAddr.length < 40) childTokenAddr = '0' + childTokenAddr;
                            childTokenAddr = '0x' + childTokenAddr;
                            miniMeTokenChild = ethConnector.web3.eth.contract( miniMeTokenHelper.miniMeTokenAbi).at(childTokenAddr);
                            cb();
                        });
                    });
            },
            function(cb) {
                ethConnector.web3.eth.getBlockNumber(function (err, _blockNumber) {
                    assert.ifError(err);
                    b[5] = _blockNumber;
                    log("b[5]->"+b[5]);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.parentToken(function(err, _parentAddress) {
                    assert.ifError(err);
                    assert.equal(_parentAddress, miniMeToken.address);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.parentSnapShotBlock(function(err, _parentSnapshotBlock) {
                    assert.ifError(err);
                    assert.equal(_parentSnapshotBlock, b[5]);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.totalSupply(function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 7);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.balanceOf(ethConnector.accounts[1], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 6);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.totalSupplyAt(b[4], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 0);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.balanceOfAt(ethConnector.accounts[2], b[4], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 0);
                    cb();
                });
            },
        ],function(err) {
            done();
        });
    });
    it('Should move tokens in the child token from 2 to 3', function(done) {
        async.series([
            function(cb) {
                miniMeTokenChild.transfer(ethConnector.accounts[2], ethConnector.web3.toWei(4), {
                    from: ethConnector.accounts[1],
                    gas: 200000},
                    function(err) {
                        assert.ifError(err);
                        cb();
                    }
                );
            },
            function(cb) {
                ethConnector.web3.eth.getBlockNumber(function (err, _blockNumber) {
                    assert.ifError(err);
                    b[6] = _blockNumber;
                    log("b[6]->"+b[6]);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.balanceOf(ethConnector.accounts[1], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 2);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.balanceOf(ethConnector.accounts[2], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 5);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOfAt(ethConnector.accounts[1], b[5], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 6);
                    cb();
                });
            },
            function(cb) {
                miniMeToken.balanceOfAt(ethConnector.accounts[2], b[5], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 1);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.balanceOfAt(ethConnector.accounts[1], b[5], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 6);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.balanceOfAt(ethConnector.accounts[2], b[5], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 1);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.balanceOfAt(ethConnector.accounts[1], b[4], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 0);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.balanceOfAt(ethConnector.accounts[2], b[4], function(err, _balance) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 0);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.totalSupply(function(err, _totalSupply) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_totalSupply), 7);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.totalSupplyAt(b[5], function(err, _totalSupply) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_totalSupply), 7);
                    cb();
                });
            },
            function(cb) {
                miniMeTokenChild.totalSupplyAt(b[4], function(err, _totalSupply) {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_totalSupply), 0);
                    cb();
                });
            }
        ],function(err) {
            done();
        });
    });
    function bcDelay(secs, cb) {
        send("evm_increaseTime", [secs], function(err, result) {
            if (err) return cb(err);

      // Mine a block so new time is recorded.
            send("evm_mine", function(err, result) {
                if (err) return cb(err);
                cb();
            });
        });
    }

    function log(S) {
        if (verbose) {
            console.log(S);
        }
    }

        // CALL a low level rpc
    function send(method, params, callback) {
        if (typeof params == "function") {
          callback = params;
          params = [];
        }

        ethConnector.web3.currentProvider.sendAsync({
          jsonrpc: "2.0",
          method: method,
          params: params || [],
          id: new Date().getTime()
        }, callback);
    }
});
