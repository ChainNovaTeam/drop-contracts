// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {BeaconProxy} from "openzeppelin-contracts/proxy/beacon/BeaconProxy.sol";

contract UpgradeableBeaconProxy is BeaconProxy {
    constructor(address beacon, bytes memory data) BeaconProxy(beacon, data) {}
}
