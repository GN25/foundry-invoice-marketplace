// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {InvoiceToken} from "src/InvoiceToken.sol";
import {InvoiceMarketplace} from "src/InvoiceMarketplace.sol";
import {InvoiceCoin} from "src/InvoiceCoin.sol";
import {DeployMarketplace} from "script/DeployMarketplace.s.sol";

contract InvoiceMarketplaceTest is Test {
    InvoiceMarketplace public market;
    InvoiceToken public token;
    InvoiceCoin public coin;

    address public owner = address(this);
    address public user = makeAddr("user");
    address public anotherUser = makeAddr("anotherUser");
    address public admin = makeAddr("deployer");

    uint256 public constant TOKEN_ID = 1;
    uint256 public constant VALUE = 100;
    uint256 public constant TIME_UNTIL_DEADLINE = 1 days;
    uint256 public constant RISK_FACTOR = 90;
    uint256 public constant RISK_PRECISION = 100;

    DeployMarketplace deployer;

    modifier minted(address to) {
        market.createInvoice(to, TOKEN_ID, VALUE, TIME_UNTIL_DEADLINE);
        _;
    }

    modifier approved(address to) {
        vm.prank(to);
        token.approve(address(market), TOKEN_ID);
        _;
    }

    modifier mintedAndApproved(address to) {
        market.createInvoice(to, TOKEN_ID, VALUE, TIME_UNTIL_DEADLINE);
        vm.prank(to);
        token.approve(address(market), TOKEN_ID);
        _;
    }

    modifier mintedAndDeposited(address depositer) {
        market.createInvoice(depositer, TOKEN_ID, VALUE, TIME_UNTIL_DEADLINE);
        vm.prank(depositer);
        token.approve(address(market), TOKEN_ID);
        vm.prank(depositer);
        market.depositInvoice(TOKEN_ID);
        _;
    }

    function setUp() public {
        deployer = new DeployMarketplace();
        deployer.run();
        market = deployer.market();
        token = deployer.token();
        coin = deployer.coin();
    }

    function testDepositInvoice() public mintedAndApproved(user) {
        vm.prank(user);
        market.depositInvoice(TOKEN_ID);
        assertEq(market.collateralAllowed(user), _getCollateralRealValue(VALUE));
    }

    function testDepositInvoiceNotOwner() public mintedAndApproved(user) {
        vm.prank(anotherUser);
        vm.expectRevert();
        market.depositInvoice(TOKEN_ID);
    }

    function _getCollateralRealValue(uint256 value) internal pure returns (uint256) {
        return (value * RISK_FACTOR) / RISK_PRECISION;
    }

    function testMintCollateralWithDepositedInvoice() public mintedAndDeposited(user) {
        uint256 collateralValue = _getCollateralRealValue(VALUE);
        vm.prank(user);
        market.mintCollateral(user, collateralValue);
        assertEq(coin.balanceOf(user), collateralValue);
    }

    function testNonMarketUserCannotMintCollateral(address nonMarketUser) public minted(user) {
        vm.assume(nonMarketUser != address(this));
        vm.prank(nonMarketUser);
        vm.expectRevert(InvoiceMarketplace.InvoiceMarketplace__NotValidUser.selector);
        market.mintCollateral(user, 1);
    }

    function testMintCollateralWithUnsuficientCollateralAllowed(uint256 amount) public mintedAndDeposited(user) {
        vm.assume(amount > 0);
        amount = bound(amount, market.collateralAllowed(user) + 1, market.collateralAllowed(user) + 1e18);
        uint256 collateralValue = _getCollateralRealValue(VALUE);
        vm.prank(user);
        vm.expectRevert(InvoiceMarketplace.InvoiceMarketplace__NotEnoughCollateral.selector);
        market.mintCollateral(user, collateralValue + amount);
    }

    function testDepositInvoiceAndMintCollateral() public mintedAndApproved(user) {
        uint256 collateralValue = _getCollateralRealValue(VALUE);
        vm.prank(user);
        market.depositInvoiceAndMintCollateral(TOKEN_ID);
        assertEq(coin.balanceOf(user), collateralValue);
    }
}
