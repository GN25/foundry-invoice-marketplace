// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {InvoiceCoin} from "src/InvoiceCoin.sol";
import {InvoiceMarketplace} from "src/InvoiceMarketplace.sol";
import {InvoiceToken} from "src/InvoiceToken.sol";
import {Test} from "forge-std/Test.sol";

contract Handler is Test {
    InvoiceMarketplace public market;
    InvoiceCoin public coin;
    InvoiceToken public token;

    uint256 public constant RISK_FACTOR = 90;
    uint256 public constant RISK_PRECISION = 100;

    uint256 public totalMintableFromCreatedInvoices;
    uint256[] public tokenIds;
    mapping(uint256 tokenId => address owner) public owner;
    mapping(uint256 tokenId => bool onSale) public onSale;
    address[] public depositors;
    address[] public withCoins;

    uint256 public numCreateSuccess;
    uint256 public numDepositSuccess;
    uint256 public numMintSuccess;
    uint256 public numDepositAndMintSuccess;
    uint256 public numBuySuccess;
    uint256 public numCreateFail;
    uint256 public numDepositFail;
    uint256 public numMintFail;
    uint256 public numDepositAndMintFail;
    uint256 public numBuyFail;

    constructor(InvoiceMarketplace _market, InvoiceCoin _coin, InvoiceToken _token) {
        market = _market;
        coin = _coin;
        token = _token;
    }

    function createInvoice(address to, uint256 tokenId, uint256 value, uint256 timeUntilDeadline) public {
        if (to == address(0)) return;

        tokenId = bound(tokenId, 1, type(uint96).max);
        value = bound(value, 1, type(uint256).max / RISK_FACTOR);
        timeUntilDeadline = bound(timeUntilDeadline, 1, type(uint96).max);

        vm.prank(market.i_minter());
        try market.createInvoice(to, tokenId, value, timeUntilDeadline) {
            totalMintableFromCreatedInvoices += (value * RISK_FACTOR) / RISK_PRECISION;
            tokenIds.push(tokenId);
            owner[tokenId] = to;
            numCreateSuccess++;
        } catch {
            numCreateFail++;
            return;
        }
    }

    function depositInvoice(uint256 tokenId) public {
        if (tokenIds.length == 0) return;
        uint256 tokenIndex = bound(tokenId, 0, tokenIds.length - 1);
        tokenId = tokenIds[tokenIndex];
        address user = owner[tokenId];
        if (user == address(0)) return;
        vm.startPrank(user);
        token.approve(address(market), tokenId);
        try market.depositInvoice(tokenId) {
            owner[tokenId] = address(market);
            depositors.push(user);
            onSale[tokenId] = true;
            numDepositSuccess++;
        } catch {
            numDepositFail++;
            vm.stopPrank();
            return;
        }
        vm.stopPrank();
    }

    function mintCoins(address user, uint256 amount) public {
        if (depositors.length == 0) return;
        uint256 userIndex = bound(uint256(uint160(user)), 0, depositors.length - 1);
        user = depositors[userIndex];

        if (market.coinsAllowed(user) == 0) return;
        amount = bound(amount, 1, market.coinsAllowed(user));
        vm.prank(user);
        try market.mintCoins(user, amount) {
            numMintSuccess++;
            withCoins.push(user);
        } catch {
            numMintFail++;
            return;
        }
    }

    function depositInvoiceAndMintCoins(uint256 tokenId) public {
        if (tokenIds.length == 0) return;
        uint256 tokenIndex = bound(tokenId, 0, tokenIds.length - 1);
        tokenId = tokenIds[tokenIndex];
        address user = owner[tokenId];
        if (user == address(0)) return;
        if (owner[tokenId] == address(market)) return;
        vm.startPrank(user);
        token.approve(address(market), tokenId);
        try market.depositInvoiceAndMintCoins(tokenId) {
            owner[tokenId] = address(market);
            depositors.push(user);
            withCoins.push(user);
            onSale[tokenId] = true;
            numDepositAndMintSuccess++;
        } catch {
            numDepositAndMintFail++;
            vm.stopPrank();
            return;
        }
        vm.stopPrank();
    }

    function buyInvoice(uint256 tokenId) public {
        if (withCoins.length == 0) return;
        uint256 userIndex = bound(tokenId, 0, withCoins.length - 1);
        address user = withCoins[userIndex];
        uint256 tokenIndex = bound(tokenId, 0, tokenIds.length - 1);
        tokenId = tokenIds[tokenIndex];
        vm.prank(user);
        try market.buyInvoice(tokenId) {
            numBuySuccess++;
            owner[tokenId] = user;
            onSale[tokenId] = false;
        } catch {
            numBuyFail++;
        }
    }

    function simulateExternalTransferOfCoins(address from, address to, uint256 amount) public {
        if (from == address(0) || to == address(0)) return;
        if (amount == 0) return;
        if (withCoins.length == 0) return;
        uint256 fromIndex = bound(uint256(uint160(from)), 0, withCoins.length - 1);
        from = withCoins[fromIndex];
        uint256 maxAmount = coin.balanceOf(from);
        if (maxAmount == 0) return;
        amount = bound(amount, 1, maxAmount);
        if (coin.balanceOf(from) < amount) return;
        vm.prank(from);
        coin.transfer(to, amount);
        withCoins.push(to);
    }

    function getNumberOfTokenIds() public view returns (uint256) {
        return tokenIds.length;
    }
}
