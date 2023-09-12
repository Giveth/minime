// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { BaseScript } from "./Base.s.sol";
import { DeploymentConfig } from "./DeploymentConfig.s.sol";

import { MiniMeToken } from "../contracts/MiniMeToken.sol";
import { MiniMeTokenFactory } from "../contracts/MiniMeToken.sol";

contract Deploy is BaseScript {
    function run()
        public
        returns (DeploymentConfig deploymentConfig, MiniMeTokenFactory minimeFactory, MiniMeToken minimeToken)
    {
        deploymentConfig = new DeploymentConfig(broadcaster);
        (
            ,
            address parentToken,
            uint256 parentSnapShotBlock,
            string memory name,
            uint8 decimals,
            string memory symbol,
            bool transferEnabled
        ) = deploymentConfig.activeNetworkConfig();

        vm.startBroadcast(broadcaster);
        minimeFactory = new MiniMeTokenFactory();
        minimeToken = new MiniMeToken(
          minimeFactory, 
          MiniMeToken(payable(parentToken)), 
          parentSnapShotBlock, 
          name, 
          decimals, 
          symbol, 
          transferEnabled
        );
        vm.stopBroadcast();
    }
}
