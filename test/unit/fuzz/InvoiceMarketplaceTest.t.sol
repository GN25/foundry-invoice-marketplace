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
    uint256 public constant DEFAULT_COINS_GIVEN = 1000000;

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

    modifier mintedAndApprovedWithParameters(address to, uint256 tokenId, uint256 value, uint256 timeUntilDeadline) {
        market.createInvoice(to, tokenId, value, timeUntilDeadline);
        vm.prank(to);
        token.approve(address(market), tokenId);
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

    modifier hasCoins(address receiver) {
        vm.assume(receiver != address(0));
        vm.prank(address(market));
        coin.mint(receiver, DEFAULT_COINS_GIVEN);
        _;
    }

    function setUp() public {
        deployer = new DeployMarketplace();
        deployer.run();
        market = deployer.market();
        token = deployer.token();
        coin = deployer.coin();
    }

    // --- createInvoice ---

    function testCreateInvoice(uint256 tokenId, uint256 value, uint256 timeUntilDeadline) public {
        vm.assume(tokenId > 0);
        vm.assume(value > 0);
        vm.assume(timeUntilDeadline > 0);
        market.createInvoice(user, tokenId, value, timeUntilDeadline);
        InvoiceToken.Invoice memory invoice = token.getInvoice(tokenId);
        uint256 id = invoice.id;
        uint256 invoiceValue = invoice.value;
        uint256 deadline = invoice.timeUntilDeadline;
        assertEq(id, tokenId);
        assertEq(invoiceValue, value);
        assertEq(deadline, timeUntilDeadline);
    }

    function testCreateInvoiceWithInvalidTokenId() public {
        uint256 tokenId = 0;
        vm.expectRevert(InvoiceToken.InvoiceToken__NotValidTokenId.selector);
        market.createInvoice(user, tokenId, VALUE, TIME_UNTIL_DEADLINE);
    }

    function testCreateInvoiceWithInvalidValue() public {
        uint256 value = 0;
        vm.expectRevert(InvoiceToken.InvoiceToken__AmountMustBeGreaterThanZero.selector);
        market.createInvoice(user, TOKEN_ID, value, TIME_UNTIL_DEADLINE);
    }

    function testCreateInvoiceWithInvalidTimeUntilDeadline() public {
        uint256 timeUntilDeadline = 0;
        vm.expectRevert(InvoiceToken.InvoiceToken__InvalidTimeUntilDeadline.selector);
        market.createInvoice(user, TOKEN_ID, VALUE, timeUntilDeadline);
    }

    function testNonMinterCannotCreateInvoice(address nonMinter, address receiver) public {
        vm.assume(nonMinter != address(this));
        vm.prank(nonMinter);
        vm.expectRevert(InvoiceMarketplace.InvoiceMarketplace__NotValidMinter.selector);
        market.createInvoice(receiver, TOKEN_ID, VALUE, TIME_UNTIL_DEADLINE);
    }

    // --- depositInvoice ---
    function testDepositInvoice() public mintedAndApproved(user) {
        vm.prank(user);
        market.depositInvoice(TOKEN_ID);
        assertEq(market.coinsAllowed(user), _getCollateralRealValue(VALUE));
    }

    function testDepositInvoiceNotOwner() public mintedAndApproved(user) {
        vm.prank(anotherUser);
        vm.expectRevert();
        market.depositInvoice(TOKEN_ID);
    }

    function testCollateralValueIsIncreasedOnDeposit(uint256 value) public {
        vm.assume(value > 0);
        value = bound(value, 1, type(uint256).max / RISK_FACTOR);

        _mintAndApproveWithParameters(user, TOKEN_ID, value, TIME_UNTIL_DEADLINE);

        uint256 collateralValue = _getCollateralRealValue(value);
        vm.prank(user);
        market.depositInvoice(TOKEN_ID);
        assertEq(market.coinsAllowed(user), collateralValue);
    }

    // --- mintCoins ---
    function testMintCoinsWithDepositedInvoice() public mintedAndDeposited(user) {
        uint256 collateralValue = _getCollateralRealValue(VALUE);
        vm.prank(user);
        market.mintCoins(user, collateralValue);
        assertEq(coin.balanceOf(user), collateralValue);
    }

    function testNonMarketUserCannotMintCoins(address attacker) public mintedAndDeposited(user) {
        vm.assume(attacker != user && attacker != address(0));
        vm.prank(attacker);
        vm.expectRevert(InvoiceMarketplace.InvoiceMarketplace__NotValidUser.selector);
        market.mintCoins(user, 1);
    }

    function testMintZeroCoins() public mintedAndDeposited(user) {
        vm.prank(user);
        vm.expectRevert(InvoiceMarketplace.InvoiceMarketplace__NoValidAmount.selector);
        market.mintCoins(user, 0);
    }

    function testUserCannotIncreaseCollateralValueWithoutDepositing(uint256 collateralValue)
        public
        mintedAndApproved(user)
    {
        collateralValue = bound(collateralValue, 1, type(uint256).max / RISK_FACTOR);
        vm.prank(user);
        vm.expectRevert(InvoiceMarketplace.InvoiceMarketplace__NotEnoughCollateral.selector);
        market.mintCoins(user, collateralValue);
    }

    function testMintCoinsWithUnsuficientCoinsAllowed(uint256 amount) public mintedAndDeposited(user) {
        vm.assume(amount > 0);
        amount = bound(amount, market.coinsAllowed(user) + 1, market.coinsAllowed(user) + 1e18);
        uint256 collateralValue = _getCollateralRealValue(VALUE);
        vm.prank(user);
        vm.expectRevert(InvoiceMarketplace.InvoiceMarketplace__NotEnoughCollateral.selector);
        market.mintCoins(user, collateralValue + amount);
    }

    function testMintingCoinsReducesCoinsAllowed(uint256 amount) public mintedAndDeposited(user) {
        vm.assume(amount > 0);
        amount = bound(amount, 1, _getCollateralRealValue(VALUE));

        uint256 initialCoinsAllowed = market.coinsAllowed(user);
        vm.prank(user);
        market.mintCoins(user, amount);
        uint256 finalCoinsAllowed = market.coinsAllowed(user);
        assertEq(finalCoinsAllowed + amount, initialCoinsAllowed);
    }

    // --- depositInvoiceAndMintCoins ---
    function testDepositInvoiceAndMintCoins() public mintedAndApproved(user) {
        uint256 collateralValue = _getCollateralRealValue(VALUE);
        vm.prank(user);
        market.depositInvoiceAndMintCoins(TOKEN_ID);
        assertEq(coin.balanceOf(user), collateralValue);
    }

    function testNonOwnerOfInvoiceCannotDepositAndMintCoins(address attacker) public {
        vm.assume(attacker != address(0));
        vm.prank(attacker);
        vm.expectRevert();
        market.depositInvoiceAndMintCoins(TOKEN_ID);
    }

    // --- buyInvoice ---

    function testBuyInvoiceAnotherUserDeposited() public mintedAndDeposited(user) hasCoins(anotherUser) {
        vm.prank(anotherUser);
        market.buyInvoice(TOKEN_ID);
        assertEq(token.ownerOf(TOKEN_ID), anotherUser);
        assertEq(coin.balanceOf(anotherUser), DEFAULT_COINS_GIVEN - _getCollateralRealValue(VALUE));
        assert(token.ownerOf(TOKEN_ID) != address(market));
        assert(token.ownerOf(TOKEN_ID) != user);
    }

    function testTryToBuyInvoiceWithoutEnoughCoins(address attacker) public mintedAndDeposited(user) {
        vm.assume(attacker != address(0));
        vm.prank(attacker);
        vm.expectRevert(InvoiceMarketplace.InvoiceMarketplace__NoInvoiceCoins.selector);
        market.buyInvoice(TOKEN_ID);
    }

    function testTryToBuyInvoiceThatIsNotOnSale(address attacker) public minted(user) hasCoins(attacker) {
        vm.assume(attacker != address(0));
        vm.prank(attacker);
        vm.expectRevert(InvoiceMarketplace.InvoiceMarketplace__TokenNotOnSale.selector);
        market.buyInvoice(TOKEN_ID);
    }

    // --- Helpers ---
    function _getCollateralRealValue(uint256 value) internal pure returns (uint256) {
        return (value * RISK_FACTOR) / RISK_PRECISION;
    }

    function _mintAndApproveWithParameters(address to, uint256 tokenId, uint256 value, uint256 timeUntilDeadline)
        internal
    {
        market.createInvoice(to, tokenId, value, timeUntilDeadline);
        vm.prank(to);
        token.approve(address(market), tokenId);
    }
}
