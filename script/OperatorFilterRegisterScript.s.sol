// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {OperatorFilterRegistry} from "src/filter/OperatorFilterRegistry.sol";

import "forge-std/Script.sol";
import "forge-std/console.sol";

// forge script script/OperatorFilterRegisterScript.sol:OperatorFilterFilterOperator  --fork-url $MAINNET_RPC_URL  RUST_BACKTRACE=1
contract OperatorFilterFilterOperator is Script {
    address operatorFilterRegisterAddress = address(0x000000000000AAeB6D7670E522A718067333cd4E);

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        OperatorFilterRegistry operatorFilterRegister = OperatorFilterRegistry(operatorFilterRegisterAddress);
        address[] memory filterOperator =
            operatorFilterRegister.filteredOperators(address(0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6));

        address subscription =
            operatorFilterRegister.subscriptionOf(address(0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6));
        console.log("========subscription==========", subscription);
        console.log("========filterOperator len==========", filterOperator.length);

        for (uint256 i = 0; i < filterOperator.length; ++i) {
            console.log("========filterOperator: ", filterOperator[i]);
        }

        vm.stopBroadcast();
    }
}
