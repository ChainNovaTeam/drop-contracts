// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {OperatorFilterRegistry} from "src/filter/OperatorFilterRegistry.sol";
import {ICreate2Deployer} from "src/interfaces/ICreate2Deployer.sol";

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

// forge script script/OperatorFilterRegisterDepolyScript.s.sol:Create2DeployerOperatorFilterRegister  --rpc-url $url --broadcast --verify --retries 10 --delay 30
contract Create2DeployerOperatorFilterRegister is Script {
    // Create2Deployer address 参看： https://github.com/pcaversaccio/create2deployer
    // 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2
    ICreate2Deployer private create2Deployer = ICreate2Deployer(0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2);

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        bytes memory initCode = type(OperatorFilterRegistry).creationCode;

        // salt
        console.logBytes32(keccak256(initCode));
        bytes32 salt = 0xd6b1f3a0e6312ad4d64a8eaade1727700b1d429b5d168a4209bc7ee73ae81c84;

        address deployed = create2Deployer.computeAddress(salt, keccak256(initCode));
        create2Deployer.deploy(0, salt, type(OperatorFilterRegistry).creationCode);
        console.log("deployed", deployed);

        vm.stopBroadcast();
    }
}

// forge script script/OperatorFilterRegisterDepolyScript.s.sol:DeployerOperatorFilterRegister  --rpc-url $url --broadcast --verify --retries 10 --delay 30
contract DeployerOperatorFilterRegister is Script {
    OperatorFilterRegistry private operatorFilterRegistry;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        operatorFilterRegistry = new OperatorFilterRegistry();
        console.log("operatorFilterRegistry:", address(operatorFilterRegistry));

        vm.stopBroadcast();
    }
}
