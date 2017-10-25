const MiniMeTokenAbi = require('../build/MiniMeToken.sol').MiniMeTokenAbi;
const MiniMeTokenByteCode = require('../build/MiniMeToken.sol').MiniMeTokenByteCode;
const generateClass = require('eth-contract-class').default;

module.exports = generateClass(MiniMeTokenAbi, MiniMeTokenByteCode);
