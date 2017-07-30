"use strict";

var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

var async = require("async");
var BigNumber = require("bignumber.js");

var _require = require("runethtx"),
    _deploy = _require.deploy,
    sendContractTx = _require.sendContractTx,
    asyncfunc = _require.asyncfunc;

var _require2 = require("../contracts/MiniMeToken.sol.js"),
    MiniMeTokenAbi = _require2.MiniMeTokenAbi,
    MiniMeTokenByteCode = _require2.MiniMeTokenByteCode,
    MiniMeTokenFactoryAbi = _require2.MiniMeTokenFactoryAbi,
    MiniMeTokenFactoryByteCode = _require2.MiniMeTokenFactoryByteCode;

module.exports = function () {
    function MiniMeToken(web3, address) {
        _classCallCheck(this, MiniMeToken);

        this.web3 = web3;
        this.contract = this.web3.eth.contract(MiniMeTokenAbi).at(address);
    }

    _createClass(MiniMeToken, [{
        key: "getState",
        value: function getState(_cb) {
            var _this = this;

            return asyncfunc(function (cb) {
                var st = {
                    balances: {}
                };
                var accounts = void 0;
                async.series([function (cb1) {
                    _this.contract.name(function (err, _name) {
                        if (err) {
                            cb1(err);return;
                        }
                        st.name = _name;
                        cb1();
                    });
                }, function (cb1) {
                    _this.contract.decimals(function (err, _decimals) {
                        if (err) {
                            cb1(err);return;
                        }
                        st.decimals = _decimals;
                        cb1();
                    });
                }, function (cb1) {
                    _this.contract.controller(function (err, _controller) {
                        if (err) {
                            cb1(err);return;
                        }
                        st.controller = _controller;
                        cb1();
                    });
                }, function (cb1) {
                    _this.web3.eth.getAccounts(function (err, _accounts) {
                        if (err) {
                            cb1(err);return;
                        }
                        accounts = _accounts;
                        cb1();
                    });
                }, function (cb1) {
                    _this.contract.totalSupply(function (err, _totalSupply) {
                        if (err) {
                            cb1(err);return;
                        }
                        st.totalSupply = _totalSupply.div(new BigNumber(10).pow(st.decimals)).toNumber();
                        cb1();
                    });
                }, function (cb1) {
                    _this.contract.parentToken(function (err, _parentToken) {
                        if (err) {
                            cb1(err);return;
                        }
                        st.parentToken = _parentToken;
                        cb1();
                    });
                }, function (cb1) {
                    _this.contract.parentSnapShotBlock(function (err, _parentSnapShotBlock) {
                        if (err) {
                            cb1(err);return;
                        }
                        st.parentSnapShotBlock = _parentSnapShotBlock;
                        cb1();
                    });
                }, function (cb1) {
                    async.eachSeries(accounts, function (account, cb2) {
                        _this.contract.balanceOf(account, function (err, res) {
                            if (err) {
                                cb2(err);return;
                            }
                            st.balances[account] = res.div(new BigNumber(10).pow(st.decimals)).toNumber();
                            cb2();
                        });
                    }, cb1);
                }], function (err2) {
                    cb(err2, st);
                });
            }, _cb);
        }
    }, {
        key: "createCloneToken",
        value: function createCloneToken(opts, _cb) {
            var _this2 = this;

            return asyncfunc(function (cb) {
                sendContractTx(_this2.web3, _this2.contract, "createCloneToken", opts, function (err2, txHash) {
                    if (err2) {
                        cb(err2);
                        return;
                    }
                    var firstSend = new Date().getTime();
                    var getTransactionReceiptCB = function getTransactionReceiptCB(err3, res) {
                        if (err3) {
                            cb(err3);
                            return;
                        }
                        if (!res) {
                            var now = new Date().getTime();
                            if (now - firstSend > 900000) {
                                cb(new Error("Timeout mining transaction"));
                                return;
                            }
                            setTimeout(function () {
                                _this2.web3.eth.getTransactionReceipt(txHash, getTransactionReceiptCB);
                            }, 200);
                            return;
                        }
                        var cloneTokenAddr = _this2.web3.toBigNumber(res.logs[0].topics[1]).toString(16);
                        while (cloneTokenAddr.length < 40) {
                            cloneTokenAddr = "0" + cloneTokenAddr;
                        }cloneTokenAddr = "0x" + cloneTokenAddr;
                        var miniMeTokenClone = new MiniMeToken(_this2.web3, cloneTokenAddr);
                        cb(null, miniMeTokenClone);
                    };
                    _this2.web3.eth.getTransactionReceipt(txHash, getTransactionReceiptCB);
                });
            }, _cb);
        }
    }, {
        key: "convertAmountAndSend",
        value: function convertAmountAndSend(method, opts, _cb) {
            var _this3 = this;

            return asyncfunc(function (cb) {
                _this3.contract.decimals(function (err, _decimals) {
                    if (err) {
                        cb(err);
                        return;
                    }
                    var params = Object.assign({}, opts);
                    params.amount = new BigNumber(10).pow(_decimals).mul(params.amount);
                    sendContractTx(_this3.web3, _this3.contract, method, params, function (err2, txHash) {
                        if (err2) {
                            cb(err2);
                            return;
                        }
                        cb(null, txHash);
                    });
                });
            }, _cb);
        }
    }, {
        key: "transfer",
        value: function transfer(opts, cb) {
            return this.convertAmountAndSend("transfer", opts, cb);
        }
    }, {
        key: "generateTokens",
        value: function generateTokens(opts, cb) {
            return this.convertAmountAndSend("generateTokens", opts, cb);
        }
    }, {
        key: "destroyTokens",
        value: function destroyTokens(opts, cb) {
            var params = Object.assign({}, opts);
            params.extraGas = 50000;
            return this.convertAmountAndSend("destroyTokens", params, cb);
        }
    }, {
        key: "approve",
        value: function approve(opts, cb) {
            return this.convertAmountAndSend("approve", opts, cb);
        }
    }, {
        key: "allowance",
        value: function allowance(opts, _cb) {
            var _this4 = this;

            return asyncfunc(function (cb) {
                var decimals = void 0;
                var allowance = void 0;
                async.series([function (cb1) {
                    _this4.contract.decimals(function (err, _decimals) {
                        if (err) {
                            cb1(err);
                            return;
                        }
                        decimals = _decimals;
                        cb1();
                    });
                }, function (cb1) {
                    _this4.contract.allowance(opts.owner, opts.spender, function (err, res) {
                        if (err) {
                            cb1(err);
                            return;
                        }
                        allowance = res.div(new BigNumber(10).pow(decimals)).toNumber();
                        cb1();
                    });
                }], function (err2) {
                    if (err2) {
                        cb(err2);
                    } else {
                        cb(null, allowance);
                    }
                });
            }, _cb);
        }
    }], [{
        key: "deploy",
        value: function deploy(web3, opts, _cb) {
            return asyncfunc(function (cb) {
                var params = Object.assign({}, opts);
                params.parentToken = params.parentToken || 0;
                params.parentSnapShotBlock = params.parentSnapShotBlock || 0;
                params.transfersEnabled = typeof params.transfersEnabled === "undefined" ? true : params.transfersEnabled;
                async.series([function (cb1) {
                    params.abi = MiniMeTokenFactoryAbi;
                    params.byteCode = MiniMeTokenFactoryByteCode;
                    _deploy(web3, params, function (err, _tokenFactory) {
                        if (err) {
                            cb1(err);
                            return;
                        }
                        params.tokenFactory = _tokenFactory.address;
                        cb1();
                    });
                }, function (cb1) {
                    params.abi = MiniMeTokenAbi;
                    params.byteCode = MiniMeTokenByteCode;
                    _deploy(web3, params, cb1);
                }], function (err, res) {
                    if (err) {
                        cb(err);
                        return;
                    }
                    var minime = new MiniMeToken(web3, res[1].address);
                    cb(null, minime);
                });
            }, _cb);
        }
    }]);

    return MiniMeToken;
}();
