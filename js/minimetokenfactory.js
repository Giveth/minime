const MiniMeTokenFactoryAbi = require('../build/MiniMeToken.sol').MiniMeTokenFactoryAbi;
const MiniMeTokenFactoryByteCode = require('../build/MiniMeToken.sol').MiniMeTokenFactoryByteCode;
const generateClass = require('eth-contract-class').default;

module.exports = generateClass(MiniMeTokenFactoryAbi, MiniMeTokenFactoryByteCode);
