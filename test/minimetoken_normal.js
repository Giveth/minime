import ethConnector from "ethconnector";
import assert from "assert"; // node.js core module
import async from "async";

import MiniMeToken from "../js/minimetoken";

const verbose = false;

// b[0]  ->  0, 0, 0, 0
// b[1]  ->  0,10, 0, 0
// b[2]  ->  0, 8, 2, 0
// b[3]  ->  0, 9, 1, 0
// b[4]  ->  0, 6, 1, 0
//  Clone token
// b[5]  ->  0, 6, 1, 0
// b[6]  ->  0, 2, 5. 0

describe("MiniMeToken test", () => {
    let miniMeToken;
    let miniMeTokenClone;
    const b = [];

    before((done) => {
        ethConnector.init("testrpc", { gasLimit: 4000000 }, done);
    });
    it("should deploy all the contracts", (done) => {
        MiniMeToken.deploy(ethConnector.web3, {
            tokenName: "MiniMe Test Token",
            decimalUnits: 18,
            tokenSymbol: "MMT",
        }, (err, _miniMeToken) => {
            assert.ifError(err);
            assert.ok(_miniMeToken.contract.address);
            miniMeToken = _miniMeToken;
            done();
        });
    }).timeout(20000);

    it("Should generate tokens for address 1", (done) => {
        async.series([
            (cb) => {
                ethConnector.web3.eth.getBlockNumber((err, _blockNumber) => {
                    assert.ifError(err);
                    b[ 0 ] = _blockNumber;
                    log("b[0]->" + b[ 0 ]);
                    cb();
                });
            },
            (cb) => {
                miniMeToken.generateTokens({
                    owner: ethConnector.accounts[ 1 ],
                    amount: 10,
                    from: ethConnector.accounts[ 0 ],
                }, cb);
            },
            (cb) => {
                miniMeToken.getState((err, _st) => {
                    assert.ifError(err);
                    assert.equal(_st.totalSupply, 10);
                    assert.equal(_st.balances[ ethConnector.accounts[ 1 ] ], 10);
                    cb();
                });
            },
            (cb) => {
                ethConnector.web3.eth.getBlockNumber((err, _blockNumber) => {
                    assert.ifError(err);
                    b[ 1 ] = _blockNumber;
                    log("b[1]->" + b[ 1 ]);
                    cb();
                });
            },
        ], done);
    }).timeout(6000);
    it("Should transfer tokens from address 1 to address 2", (done) => {
        async.series([
            (cb) => {
                miniMeToken.transfer({
                    to: ethConnector.accounts[ 2 ],
                    from: ethConnector.accounts[ 1 ],
                    amount: 2,
                }, cb);
            },
            (cb) => {
                ethConnector.web3.eth.getBlockNumber((err, _blockNumber) => {
                    assert.ifError(err);
                    b[ 2 ] = _blockNumber;
                    log("b[2]->" + b[ 2 ]);
                    cb();
                });
            },
            (cb) => {
                miniMeToken.getState((err, _st) => {
                    assert.ifError(err);
                    assert.equal(_st.totalSupply, 10);
                    assert.equal(_st.balances[ ethConnector.accounts[ 1 ] ], 8);
                    assert.equal(_st.balances[ ethConnector.accounts[ 2 ] ], 2);
                    cb();
                });
            },
            (cb) => {
                miniMeToken.contract.balanceOfAt(
                    ethConnector.accounts[ 1 ],
                    b[ 1 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance).toNumber(), 10);
                        cb();
                    });
            },
        ], done);
    }).timeout(6000);
    it("Should allow and transfer tokens from address 2 to address 1 allowed to 3", (done) => {
        async.series([
            (cb) => {
                miniMeToken.approve({
                    spender: ethConnector.accounts[ 3 ],
                    amount: 2,
                    from: ethConnector.accounts[ 2 ],
                }, cb);
            },
            (cb) => {
                miniMeToken.allowance({
                    owner: ethConnector.accounts[ 2 ],
                    spender: ethConnector.accounts[ 3 ],
                }, (err, _allowed) => {
                    assert.ifError(err);
                    assert.equal(_allowed, 2);
                    cb();
                });
            },
            (cb) => {
                miniMeToken.contract.transferFrom(
                    ethConnector.accounts[ 2 ],
                    ethConnector.accounts[ 1 ],
                    ethConnector.web3.toWei(1),
                    {
                        from: ethConnector.accounts[ 3 ],
                        gas: 200000,
                    }, (err) => {
                        assert.ifError(err);
                        cb();
                    });
            },
            (cb) => {
                miniMeToken.allowance({
                    owner: ethConnector.accounts[ 2 ],
                    spender: ethConnector.accounts[ 3 ],
                }, (err, _allowed) => {
                    assert.ifError(err);
                    assert.equal(_allowed, 1);
                    cb();
                });
            },
            (cb) => {
                ethConnector.web3.eth.getBlockNumber((err, _blockNumber) => {
                    assert.ifError(err);
                    b[ 3 ] = _blockNumber;
                    log("b[3]->" + b[ 3 ]);
                    cb();
                });
            },
            (cb) => {
                miniMeToken.getState((err, _st) => {
                    assert.ifError(err);
                    assert.equal(_st.totalSupply, 10);
                    assert.equal(_st.balances[ ethConnector.accounts[ 1 ] ], 9);
                    assert.equal(_st.balances[ ethConnector.accounts[ 2 ] ], 1);
                    cb();
                });
            },
            (cb) => {
                miniMeToken.contract.balanceOfAt(ethConnector.accounts[ 1 ], b[ 2 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 8);
                        cb();
                    });
            },
            (cb) => {
                miniMeToken.contract.balanceOfAt(ethConnector.accounts[ 2 ], b[ 2 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 2);
                        cb();
                    });
            },
            (cb) => {
                miniMeToken.contract.balanceOfAt(ethConnector.accounts[ 1 ], b[ 1 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 10);
                        cb();
                    });
            },
            (cb) => {
                miniMeToken.contract.balanceOfAt(ethConnector.accounts[ 2 ], b[ 1 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 0);
                        cb();
                    });
            },
            (cb) => {
                miniMeToken.contract.balanceOfAt(ethConnector.accounts[ 1 ], b[ 0 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 0);
                        cb();
                    });
            },
            (cb) => {
                miniMeToken.contract.balanceOfAt(ethConnector.accounts[ 2 ], b[ 0 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 0);
                        cb();
                    });
            },
            (cb) => {
                miniMeToken.contract.balanceOfAt(ethConnector.accounts[ 1 ], 0,
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 0);
                        cb();
                    });
            },
            (cb) => {
                miniMeToken.contract.balanceOfAt(ethConnector.accounts[ 2 ], 0,
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 0);
                        cb();
                    });
            },
        ], done);
    });
    it("Should Destroy 3 tokens from 1 and 1 from 2", (done) => {
        async.series([
            (cb) => {
                miniMeToken.destroyTokens({
                    owner: ethConnector.accounts[ 1 ],
                    amount: 3,
                    from: ethConnector.accounts[ 0 ],
                }, cb);
            },
            (cb) => {
                ethConnector.web3.eth.getBlockNumber((err, _blockNumber) => {
                    assert.ifError(err);
                    b[ 4 ] = _blockNumber;
                    log("b[4]->" + b[ 4 ]);
                    cb();
                });
            },
            (cb) => {
                miniMeToken.getState((err, _st) => {
                    assert.ifError(err);
                    assert.equal(_st.totalSupply, 7);
                    assert.equal(_st.balances[ ethConnector.accounts[ 1 ] ], 6);
                    cb();
                });
            },
        ], done);
    });

    it("Should Create the clone token", (done) => {
        async.series([
            (cb) => {
                miniMeToken.createCloneToken({
                    cloneTokenName: "Clone Token 1",
                    cloneDecimalUnits: 18,
                    cloneTokenSymbol: "MMTc",
                    snapshotBlock: Number.MAX_SAFE_INTEGER,
                    transfersEnabled: true,
                }, (err, _miniMeTokenClone) => {
                    assert.ifError(err);
                    miniMeTokenClone = _miniMeTokenClone;
                    cb();
                });
            },
            (cb) => {
                ethConnector.web3.eth.getBlockNumber((err, _blockNumber) => {
                    assert.ifError(err);
                    b[ 5 ] = _blockNumber;
                    log("b[5]->" + b[ 5 ]);
                    cb();
                });
            },
            (cb) => {
                miniMeTokenClone.getState((err, _st) => {
                    assert.ifError(err);
                    assert.equal(_st.parentToken, miniMeToken.contract.address);
                    assert.equal(_st.parentSnapShotBlock, b[ 5 ]);
                    assert.equal(_st.totalSupply, 7);
                    assert.equal(_st.balances[ ethConnector.accounts[ 1 ] ], 6);
                    cb();
                });
            },
            (cb) => {
                miniMeTokenClone.contract.totalSupplyAt(b[ 4 ], (err, _balance) => {
                    assert.ifError(err);
                    assert.equal(ethConnector.web3.fromWei(_balance), 0);
                    cb();
                });
            },
            (cb) => {
                miniMeTokenClone.contract.balanceOfAt(ethConnector.accounts[ 2 ], b[ 4 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 0);
                        cb();
                    });
            },
        ], done);
    }).timeout(6000000);
    it("Should move tokens in the clone token from 2 to 3", (done) => {
        async.series([
            (cb) => {
                miniMeTokenClone.transfer({
                    to: ethConnector.accounts[ 2 ],
                    amount: 4,
                    from: ethConnector.accounts[ 1 ],
                }, cb);
            },
            (cb) => {
                ethConnector.web3.eth.getBlockNumber((err, _blockNumber) => {
                    assert.ifError(err);
                    b[ 6 ] = _blockNumber;
                    log("b[6]->" + b[ 6 ]);
                    cb();
                });
            },
            (cb) => {
                miniMeTokenClone.getState((err, _st) => {
                    assert.ifError(err);
                    assert.equal(_st.totalSupply, 7);
                    assert.equal(_st.balances[ ethConnector.accounts[ 1 ] ], 2);
                    assert.equal(_st.balances[ ethConnector.accounts[ 2 ] ], 5);
                    cb();
                });
            },
            (cb) => {
                miniMeToken.contract.balanceOfAt(ethConnector.accounts[ 1 ], b[ 5 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 6);
                        cb();
                    });
            },
            (cb) => {
                miniMeToken.contract.balanceOfAt(ethConnector.accounts[ 2 ], b[ 5 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 1);
                        cb();
                    });
            },
            (cb) => {
                miniMeTokenClone.contract.balanceOfAt(ethConnector.accounts[ 1 ], b[ 5 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 6);
                        cb();
                    });
            },
            (cb) => {
                miniMeTokenClone.contract.balanceOfAt(ethConnector.accounts[ 2 ], b[ 5 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 1);
                        cb();
                    });
            },
            (cb) => {
                miniMeTokenClone.contract.balanceOfAt(ethConnector.accounts[ 1 ], b[ 4 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 0);
                        cb();
                    });
            },
            (cb) => {
                miniMeTokenClone.contract.balanceOfAt(ethConnector.accounts[ 2 ], b[ 4 ],
                    (err, _balance) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_balance), 0);
                        cb();
                    });
            },
            (cb) => {
                miniMeTokenClone.contract.totalSupplyAt(b[ 5 ],
                    (err, _totalSupply) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_totalSupply), 7);
                        cb();
                    });
            },
            (cb) => {
                miniMeTokenClone.contract.totalSupplyAt(b[ 4 ],
                    (err, _totalSupply) => {
                        assert.ifError(err);
                        assert.equal(ethConnector.web3.fromWei(_totalSupply), 0);
                        cb();
                    });
            },
        ], done);
    });

    function log(S) {
        if (verbose) {
            console.log(S);
        }
    }
});
