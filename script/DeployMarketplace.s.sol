// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {InvoiceMarketplace} from "src/InvoiceMarketplace.sol";
import {InvoiceToken} from "src/InvoiceToken.sol";
import {InvoiceCoin} from "src/InvoiceCoin.sol";

contract DeployMarketplace is Script {
    InvoiceMarketplace public market;
    InvoiceToken public token;
    InvoiceCoin public coin;

    function deploy(address deployer) public {
        token = new InvoiceToken();
        coin = new InvoiceCoin();
        market = new InvoiceMarketplace(address(coin), address(token), address(deployer));

        token.transferOwnership(address(market));
        coin.transferOwnership(address(market));
    }

    function run() external {
        address deployer = msg.sender;
        vm.startBroadcast();
        deploy(deployer);
        vm.stopBroadcast();
    }
}
