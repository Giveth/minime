import async from "async";
import BigNumber from "bignumber.js";
import { deploy, send } from "runethtx";
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

    getState(cb) {
        const promise = new Promise((resolve, reject) => {
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
                if (err2) {
                    reject(err2);
                } else {
                    resolve(st);
                }
            });
        });

        if (cb) {
            promise.then(
                (value) => {
                    cb(null, value);
                },
                (reason) => {
                    cb(reason);
                });
        } else {
            return promise;
        }
    }

    static deploy(web3, opts, cb) {
        const promise = new Promise((resolve, reject) => {
            const params = Object.assign({}, opts);
            params.parentToken = params.parentToken || 0;
            params.parentSnapShotBlock = params.parentSnapShotBlock || 0;
            params.transfersEnabled = (typeof params.transfersEnabled === "undefined") ? true : params.transfersEnabled;
            console.log("1-> "+JSON.stringify(params, null, 2));
            console.log("2-> "+typeof params.transfersEnabled);
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
                    reject(err);
                    return;
                }
                const minime = new MiniMeToken(web3, res[ 1 ].address);
                resolve(minime);
            });
        });

        if (cb) {
            promise.then(
                (value) => {
                    cb(null, value);
                },
                (reason) => {
                    cb(reason);
                });
        } else {
            return promise;
        }
    }

    createCloneToken(opts, cb) {
        const params = Object.assign({}, opts, {
            contract: this.contract,
            method: "createCloneToken",
            extraGas: 5000,
        });
        const promise = new Promise((resolve, reject) => {
            send(params, (err2, txHash) => {
                if (err2) {
                    reject(err2);
                    return;
                }
                this.web3.eth.getTransactionReceipt(txHash, (err3, res) => {
                    if (err3) {
                        reject(err3);
                        return;
                    }
                    let cloneTokenAddr =
                        this.web3.toBigNumber(res.logs[ 0 ].topics[ 1 ]).toString(16);
                    while (cloneTokenAddr.length < 40) cloneTokenAddr = "0" + cloneTokenAddr;
                    cloneTokenAddr = "0x" + cloneTokenAddr;
                    const miniMeTokenClone = new MiniMeToken(this.web3, cloneTokenAddr);
                    resolve(miniMeTokenClone);
                });
            });
        });

        if (cb) {
            promise.then(
                (value) => {
                    cb(null, value);
                },
                (reason) => {
                    cb(reason);
                });
        } else {
            return promise;
        }
    }

    convertAmountAndSend(method, opts, cb) {
        const promise = new Promise((resolve, reject) => {
            const params = Object.assign({}, opts, {
                contract: this.contract,
                method,
            });
            this.contract.decimals((err, _decimals) => {
                if (err) {
                    reject(err);
                    return;
                }
                params.amount = new BigNumber(10).pow(_decimals).mul(params.amount);
                send(params, (err2, txHash) => {
                    if (err2) {
                        reject(err2);
                        return;
                    }
                    resolve(txHash);
                });
            });
        });

        if (cb) {
            promise.then(
                (value) => {
                    cb(null, value);
                },
                (reason) => {
                    cb(reason);
                });
        } else {
            return promise;
        }
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

    allowance(opts, cb) {
        const promise = new Promise((resolve, reject) => {
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
                    reject(err2);
                } else {
                    resolve(allowance);
                }
            });
        });

        if (cb) {
            promise.then(
                (value) => {
                    cb(null, value);
                },
                (reason) => {
                    cb(reason);
                });
        } else {
            return promise;
        }
    }
}
