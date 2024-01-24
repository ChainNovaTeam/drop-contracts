// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "openzeppelin-contracts/utils/Strings.sol";
import {Vm, VmSafe} from "forge-std/Vm.sol";

/// @dev 需要将私钥和地址放到项目根目录下的 .env 文件，并遵循格式 `PRIVATE_KEY_0` `ADDRESS_0`
/// 可以使用脚本 `script/wallet/create_eth_wallet.py` 生成 .env和 公私钥、地址
library KeyEnvLib {
    using Strings for uint256;

    // Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    // @dev see forge-std/Base.sol
    Vm internal constant vm = Vm(VM_ADDRESS);

    function getEnvPrivateKeys(uint256 count) internal view returns (bytes[] memory privateKeys) {
        privateKeys = new bytes[](count);
        for (uint256 i = 0; i < count; ++i) {
            privateKeys[i] = vm.envBytes(string.concat("PRIVATE_KEY_", i.toString()));
        }
    }

    /// @notice 使用forge从.env文件中加载 私钥
    function getEnvPrivateKeysForUint(uint256 count) internal view returns (uint256[] memory privateKeys) {
        privateKeys = new uint256[](count);
        for (uint256 i = 0; i < count; ++i) {
            privateKeys[i] = vm.envUint(string.concat("PRIVATE_KEY_", i.toString()));
        }
    }

    /// @notice 使用forge从.env文件中加载 address
    function getEnvAddresses(uint256 count) internal view returns (address[] memory addresses) {
        addresses = new address[](count);
        for (uint256 i = 0; i < count; ++i) {
            addresses[i] = vm.envAddress(string.concat("ADDRESS_", i.toString()));
        }
    }
}
