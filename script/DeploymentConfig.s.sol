//// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

contract DeploymentConfig is Script {
    error DeploymentConfig_InvalidDeployerAddress();
    error DeploymentConfig_NoConfigForChain(uint256);

    struct NetworkConfig {
        address deployer;
    }

    NetworkConfig public activeNetworkConfig;

    address private deployer;

    constructor(address _broadcaster) {
        if (block.chainid == 31_337) {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        } else {
            revert DeploymentConfig_NoConfigForChain(block.chainid);
        }
        if (_broadcaster == address(0)) revert DeploymentConfig_InvalidDeployerAddress();
        deployer = _broadcaster;
    }

    function getOrCreateAnvilEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({ deployer: deployer });
    }

    // This function is a hack to have it excluded by `forge coverage` until
    // https://github.com/foundry-rs/foundry/issues/2988 is fixed.
    // See: https://github.com/foundry-rs/foundry/issues/2988#issuecomment-1437784542
    // for more info.
    // solhint-disable-next-line
    function test() public { }
}
