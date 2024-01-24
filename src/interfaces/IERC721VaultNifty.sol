// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IVaultNiftyTokenContractMetadata} from "src/interfaces/IVaultNiftyTokenContractMetadata.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC721AQueryableUpgradeable} from "ERC721A-Upgradeable/extensions/IERC721AQueryableUpgradeable.sol";

interface IERC721VaultNifty is IVaultNiftyTokenContractMetadata {
    function mintVaultNiftyDrop(address to, uint256 quantity) external;

    function totalMinted() external view returns (uint256);

    function totalBurned() external view returns (uint256);

    function numberMinted(address owner) external view returns (uint256);
}
