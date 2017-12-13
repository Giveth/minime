/**
 * Populate these after the contracts are deployed.
 * Add the address of the token and tokenFactory here.
 */
const contract_defaults = {
    tokenFactory: '',                 // Address of tokenFactory contract.
    token: '',                        // Address of token.
};

const deployment_defaults = {
    testnet: 'http://localhost:8545', // Change this to whichever testnet you want to use.
};

const token_defaults = {
    /**
     * The contract from which the current tokens are being cloned.
     * Should be 0 during deployment.
     */
    parentToken: 0,
    /**
     * Block number from which the contract is cloned from
     * Should be 0 during deployment.
     */
    parentSnapShotBlock: 0,
    tokenName: 'BinaryToken',
    decimalUnits: 18,
    tokenSymbol: 'BINC',
    /**
     * Are the transfers enabled after the deployment of contract?
     * This can be later toggled by contract deployer (Address which deployed the contract).
     */
    transfersEnabled: true
};

module.exports = {
    contract_defaults,
    deployment_defaults,
    token_defaults
}
