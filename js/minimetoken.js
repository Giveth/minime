import async from "async";
import BigNumber from "bignumber.js";
import { deploy, sendContractTx, asyncfunc } from "runethtx";
import {
    MiniMeTokenAbi,
    MiniMeTokenByteCode,
    MiniMeTokenFactoryAbi,
    MiniMeTokenFactoryByteCode,
} from "../contracts/MiniMeToken.sol.js";

export default class MiniMeToken {

    constructor(web3, address) {
        this.web3 = web3;
        this.contract = this.web3.eth.contract(MiniMeTokenAbi).at(address);
    }

    getState(_cb) {
        return asyncfunc((cb) => {
            const st = {
                balances: {},
            };
            let accounts;
            async.series([
                (cb1) => {
                    this.contract.name((err, _name) => {
                        if (err) { cb1(err); return; }
                        st.name = _name;
                        cb1();
                    });
                },
                (cb1) => {
                    this.contract.decimals((err, _decimals) => {
                        if (err) { cb1(err); return; }
                        st.decimals = _decimals;
                        cb1();
                    });
                },
                (cb1) => {
                    this.contract.controller((err, _controller) => {
                        if (err) { cb1(err); return; }
                        st.controller = _controller;
                        cb1();
                    });
                },
                (cb1) => {
                    this.web3.eth.getAccounts((err, _accounts) => {
                        if (err) { cb1(err); return; }
                        accounts = _accounts;
                        cb1();
                    });
                },
                (cb1) => {
                    this.contract.totalSupply((err, _totalSupply) => {
                        if (err) { cb1(err); return; }
                        st.totalSupply =
                            _totalSupply.div(new BigNumber(10).pow(st.decimals)).toNumber();
                        cb1();
                    });
                },
                (cb1) => {
                    this.contract.parentToken((err, _parentToken) => {
                        if (err) { cb1(err); return; }
                        st.parentToken = _parentToken;
                        cb1();
                    });
                },
                (cb1) => {
                    this.contract.parentSnapShotBlock((err, _parentSnapShotBlock) => {
                        if (err) { cb1(err); return; }
                        st.parentSnapShotBlock = _parentSnapShotBlock;
                        cb1();
                    });
                },
                (cb1) => {
                    async.eachSeries(accounts, (account, cb2) => {
                        this.contract.balanceOf(account, (err, res) => {
                            if (err) { cb2(err); return; }
                            st.balances[ account ] =
                                res.div(new BigNumber(10).pow(st.decimals)).toNumber();
                            cb2();
                        });
                    }, cb1);
                },
            ], (err2) => {
                cb(err2, st);
            });
        }, _cb);
    }

    static deploy(web3, opts, _cb) {
        return asyncfunc((cb) => {
            const params = Object.assign({}, opts);
            params.parentToken = params.parentToken || 0;
            params.parentSnapShotBlock = params.parentSnapShotBlock || 0;
            params.transfersEnabled = (typeof params.transfersEnabled === "undefined") ? true : params.transfersEnabled;
            async.series([
                (cb1) => {
                    params.abi = MiniMeTokenFactoryAbi;
                    params.byteCode = MiniMeTokenFactoryByteCode;
                    deploy(web3, params, (err, _tokenFactory) => {
                        if (err) {
                            cb1(err);
                            return;
                        }
                        params.tokenFactory = _tokenFactory.address;
                        cb1();
                    });
                },
                (cb1) => {
                    params.abi = MiniMeTokenAbi;
                    params.byteCode = MiniMeTokenByteCode;
                    deploy(web3, params, cb1);
                },
            ],
            (err, res) => {
                if (err) {
                    cb(err);
                    return;
                }
                const minime = new MiniMeToken(web3, res[ 1 ].address);
                cb(null, minime);
            });
        }, _cb);
    }

    createCloneToken(opts, _cb) {
        return asyncfunc((cb) => {
            sendContractTx(
                this.web3,
                this.contract,
                "createCloneToken",
                opts,
                (err2, txHash) => {
                    if (err2) {
                        cb(err2);
                        return;
                    }
                    const firstSend = new Date().getTime();
                    const getTransactionReceiptCB = (err3, res) => {
                        if (err3) {
                            cb(err3);
                            return;
                        }
                        if (!res) {
                            const now = new Date().getTime();
                            if (now - firstSend > 900000) {
                                cb(new Error("Timeout mining transaction"));
                                return;
                            }
                            setTimeout(() => {
                                this.web3.eth.getTransactionReceipt(
                                    txHash,
                                    getTransactionReceiptCB);
                            }, 200);
                            return;
                        }
                        let cloneTokenAddr =
                            this.web3.toBigNumber(res.logs[ 0 ].topics[ 1 ]).toString(16);
                        while (cloneTokenAddr.length < 40) cloneTokenAddr = "0" + cloneTokenAddr;
                        cloneTokenAddr = "0x" + cloneTokenAddr;
                        const miniMeTokenClone = new MiniMeToken(this.web3, cloneTokenAddr);
                        cb(null, miniMeTokenClone);
                    };
                    this.web3.eth.getTransactionReceipt(txHash, getTransactionReceiptCB);
                });
        }, _cb);
    }

    convertAmountAndSend(method, opts, _cb) {
        return asyncfunc((cb) => {
            this.contract.decimals((err, _decimals) => {
                if (err) {
                    cb(err);
                    return;
                }
                const params = Object.assign({}, opts);
                params.amount = new BigNumber(10).pow(_decimals).mul(params.amount);
                sendContractTx(
                    this.web3,
                    this.contract,
                    method,
                    params,
                    (err2, txHash) => {
                        if (err2) {
                            cb(err2);
                            return;
                        }
                        cb(null, txHash);
                    });
            });
        }, _cb);
    }

    transfer(opts, cb) {
        return this.convertAmountAndSend("transfer", opts, cb);
    }

    generateTokens(opts, cb) {
        return this.convertAmountAndSend("generateTokens", opts, cb);
    }

    destroyTokens(opts, cb) {
        const params = Object.assign({}, opts);
        params.extraGas = 50000;
        return this.convertAmountAndSend("destroyTokens", params, cb);
    }

    approve(opts, cb) {
        return this.convertAmountAndSend("approve", opts, cb);
    }

    allowance(opts, _cb) {
        return asyncfunc((cb) => {
            let decimals;
            let allowance;
            async.series([
                (cb1) => {
                    this.contract.decimals((err, _decimals) => {
                        if (err) {
                            cb1(err);
                            return;
                        }
                        decimals = _decimals;
                        cb1();
                    });
                },
                (cb1) => {
                    this.contract.allowance(opts.owner, opts.spender, (err, res) => {
                        if (err) {
                            cb1(err);
                            return;
                        }
                        allowance = res.div(new BigNumber(10).pow(decimals)).toNumber();
                        cb1();
                    });
                },
            ], (err2) => {
                if (err2) {
                    cb(err2);
                } else {
                    cb(null, allowance);
                }
            });
        }, _cb);
    }
}
