/*jslint node: true */
"use strict";

var async = require('async');
var ethConnector = require('ethconnector');
var path = require('path');
var _ = require('lodash');


var miniMeTokenAbi;
var minimeToken;
var miniMeTokenFactoryAbi;
var miniMeTokenFactory;

var src;

exports.deploy = function(opts, cb) {
    var compilationResult;
    return async.series([
        function(cb) {
            ethConnector.loadSol(path.join(__dirname, "../MiniMeToken.sol"), function(err, _src) {
                if (err) return cb(err);
                src = _src;
                cb();
            });
        },
        function(cb) {
            ethConnector.applyConstants(src, opts, function(err, _src) {
                if (err) return cb(err);
                src = _src;
                cb();
            });
        },
        function(cb) {
            ethConnector.compile(src, function(err, result) {
                if (err) return cb(err);
                compilationResult = result;
                cb();
            });
        },
        function(cb) {
            miniMeTokenFactoryAbi = JSON.parse(compilationResult.MiniMeTokenFactory.interface);
            ethConnector.deploy(compilationResult.MiniMeTokenFactory.interface,
                compilationResult.MiniMeTokenFactory.bytecode,
                0,
                0,
                function(err, _miniMeTokenFactory) {
                    if (err) return cb(err);
                    miniMeTokenFactory = _miniMeTokenFactory;
                    cb();
                });
        },
        function(cb) {
            miniMeTokenAbi = JSON.parse(compilationResult.MiniMeToken.interface);
            exports.miniMeTokenAbi = miniMeTokenAbi;
            ethConnector.deploy(compilationResult.MiniMeToken.interface,
                compilationResult.MiniMeToken.bytecode,
                0,
                0,
                miniMeTokenFactory.address,
                0,
                0,
                opts.tokenName,
                opts.decimalUnits,
                opts.tokenSymbol,
                opts.isConstant || false,
                function(err, _minimeToken) {
                    if (err) return cb(err);
                    minimeToken = _minimeToken;
                    cb();
                });
        }
    ], function(err) {
        if (err) return cb(err);
        cb(null,minimeToken, compilationResult);
    });
};
