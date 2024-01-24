// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/**
 * @title  TestERC20
 * @notice Test contract to test ERC20 as paymentTokenAddress for drop
 */
contract TestERC20 is Ownable, ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) Ownable() {}

    function mint(address account, uint256 value) public {
        _mint(account, value);
    }
}
