// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {ElectionFactory} from "../src/ElectionFactory.sol";

contract DeployElectionFactory is Script {
    function run() external returns (ElectionFactory) {
        vm.startBroadcast();
        ElectionFactory electionFactory = new ElectionFactory();
        vm.stopBroadcast();

        return electionFactory;
    }
}
