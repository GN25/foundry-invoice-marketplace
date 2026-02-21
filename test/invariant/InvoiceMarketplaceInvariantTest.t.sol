// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {InvoiceCoin} from "src/InvoiceCoin.sol";
import {InvoiceMarketplace} from "src/InvoiceMarketplace.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {InvoiceToken} from "src/InvoiceToken.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployMarketplace} from "script/DeployMarketplace.s.sol";
import {Handler} from "test/invariant/Handler.t.sol";

contract InvoiceMarketplaceInvariantTest is StdInvariant, Test {
    InvoiceMarketplace public market;
    InvoiceCoin public coin;
    InvoiceToken public token;
    DeployMarketplace deployer;
    Handler public handler;

    function setUp() public {
        deployer = new DeployMarketplace();
        deployer.run();

        market = deployer.market();
        token = deployer.token();
        coin = deployer.coin();

        handler = new Handler(market, coin, token);
        targetContract(address(handler));
    }

    function invariant_totalCoinsMintedMustBeLessOrEqualValueOfInvoices() public view {
        uint256 totalCoins = coin.totalSupply();
        uint256 totalInvoiceMintable = handler.totalMintableFromCreatedInvoices();

        assertLe(totalCoins, totalInvoiceMintable, "Total coins > total invoice mintable value");

        console.log("Total Create Success", handler.numCreateSuccess());
        console.log("Total Deposit Success", handler.numDepositSuccess());
        console.log("Total Mint Success", handler.numMintSuccess());
        console.log("Total Deposit and Mint Success", handler.numDepositAndMintSuccess());
        console.log("Total Buy Success", handler.numBuySuccess());
        console.log("Total Create Revert", handler.numCreateFail());
        console.log("Total Deposit Revert", handler.numDepositFail());
        console.log("Total Mint Revert", handler.numMintFail());
        console.log("Total Deposit and Mint Revert", handler.numDepositAndMintFail());
        console.log("Total Buy Revert", handler.numBuyFail());
    }

    function invariant_ownerOfAllOnSaleTokensMustBeMarketplace() public view {
        uint256 numOfTokenIds = handler.getNumberOfTokenIds();
        for (uint256 i = 0; i < numOfTokenIds; i++) {
            uint256 tokenId = handler.tokenIds(i);
            if (handler.onSale(tokenId)) {
                assertEq(token.ownerOf(tokenId), address(market), "Owner of deposited token is not the marketplace");
            }
        }

        console.log("Total Create Success", handler.numCreateSuccess());
        console.log("Total Deposit Success", handler.numDepositSuccess());
        console.log("Total Mint Success", handler.numMintSuccess());
        console.log("Total Deposit and Mint Success", handler.numDepositAndMintSuccess());
        console.log("Total Buy Success", handler.numBuySuccess());
        console.log("Total Create Revert", handler.numCreateFail());
        console.log("Total Deposit Revert", handler.numDepositFail());
        console.log("Total Mint Revert", handler.numMintFail());
        console.log("Total Deposit and Mint Revert", handler.numDepositAndMintFail());
        console.log("Total Buy Revert", handler.numBuyFail());
    }
}
