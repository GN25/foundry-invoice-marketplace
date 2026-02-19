// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {InvoiceToken} from "src/InvoiceToken.sol";
import {Test, console} from "forge-std/Test.sol";

contract InvoiceTokenTest is Test {
    InvoiceToken public invoiceToken;
    address public owner = address(this);
    address public user = makeAddr("user");
    address public anotherUser = makeAddr("anotherUser");
    address public thirdUser = makeAddr("thirdUser");

    uint256 public constant TOKEN_ID = 1;
    uint256 public constant VALUE = 100;
    uint256 public constant TIME_UNTIL_DEADLINE = 1 days;

    modifier minted(address to) {
        invoiceToken.mint(to, TOKEN_ID, VALUE, TIME_UNTIL_DEADLINE);
        _;
    }

    function setUp() public {
        invoiceToken = new InvoiceToken();
    }

    function testOwnerCanMint(uint256 tokenId, uint256 value, uint256 timeUntilDeadline) public {
        vm.assume(timeUntilDeadline > 0);
        vm.assume(value > 0);
        vm.assume(tokenId != 0);
        invoiceToken.mint(user, tokenId, value, timeUntilDeadline);
        assertEq(invoiceToken.ownerOf(tokenId), user);
    }

    function testNonOwnerCannotMint(uint256 tokenId, uint256 value, uint256 timeUntilDeadline) public {
        vm.assume(timeUntilDeadline > 0);
        vm.assume(value > 0);
        vm.prank(user);
        vm.expectRevert();
        invoiceToken.mint(user, tokenId, value, timeUntilDeadline);
    }

    function testTransferBetweenUsers() public minted(user) {
        vm.prank(user);
        invoiceToken.safeTransferFrom(user, anotherUser, TOKEN_ID);
        assertEq(invoiceToken.ownerOf(TOKEN_ID), anotherUser);
    }

    function testNonPropietaryCannotTransfer() public minted(user) {
        vm.prank(anotherUser);
        vm.expectRevert();
        invoiceToken.safeTransferFrom(user, anotherUser, TOKEN_ID);
    }

    function testNonPropietaryCannotStealTransfer() public minted(user) {
        vm.prank(anotherUser);
        vm.expectRevert();
        invoiceToken.safeTransferFrom(user, anotherUser, TOKEN_ID);
    }

    function testGetInvoice(uint256 tokenId, uint256 value, uint256 timeUntilDeadline) public {
        vm.assume(timeUntilDeadline > 0);
        vm.assume(value > 0);
        vm.assume(tokenId != 0);
        invoiceToken.mint(user, tokenId, value, timeUntilDeadline);
        InvoiceToken.Invoice memory invoice = invoiceToken.getInvoice(tokenId);
        assertEq(invoice.id, tokenId);
        assertEq(invoice.value, value);
        assertEq(invoice.timeUntilDeadline, timeUntilDeadline);
        assertEq(invoice.isPaid, false);
    }

    function testGetInvoiceNonExistentToken(uint256 tokenId) public {
        vm.expectRevert(InvoiceToken.InvoiceToken__TokenDoesNotExist.selector);
        invoiceToken.getInvoice(tokenId);
    }

    function testCannotDuplicateTokenId(uint256 tokenId, uint256 value, uint256 timeUntilDeadline) public {
        vm.assume(timeUntilDeadline > 0);
        vm.assume(value > 0);
        vm.assume(tokenId != 0);
        invoiceToken.mint(user, tokenId, value, timeUntilDeadline);
        vm.expectRevert(InvoiceToken.InvoiceToken__NotValidTokenId.selector);
        invoiceToken.mint(user, tokenId, value, timeUntilDeadline);
    }

    function testTransferFrom() public minted(user) {
        vm.prank(user);
        invoiceToken.approve(anotherUser, TOKEN_ID);
        vm.prank(anotherUser);
        invoiceToken.safeTransferFrom(user, anotherUser, TOKEN_ID);
        assertEq(invoiceToken.ownerOf(TOKEN_ID), anotherUser);
    }

    function testApproveNonOwner() public minted(user) {
        vm.prank(anotherUser);
        vm.expectRevert(InvoiceToken.InvoiceToken__NotOwner.selector);
        invoiceToken.approve(anotherUser, TOKEN_ID);
    }

    function testTransferNotAllowed() public minted(user) {
        vm.prank(user);
        invoiceToken.approve(anotherUser, TOKEN_ID);
        vm.prank(thirdUser);
        vm.expectRevert();
        invoiceToken.safeTransferFrom(user, anotherUser, TOKEN_ID);
    }

    function testMintInvalidTimeUntilDeadline(uint256 tokenId, uint256 value, uint256 timeUntilDeadline) public {
        vm.assume(timeUntilDeadline <= 0);
        vm.assume(value > 0);
        vm.assume(tokenId != 0);
        vm.expectRevert(InvoiceToken.InvoiceToken__InvalidTimeUntilDeadline.selector);
        invoiceToken.mint(user, tokenId, value, timeUntilDeadline);
    }

    function testMintInvalidValue(uint256 tokenId, uint256 value, uint256 timeUntilDeadline) public {
        vm.assume(timeUntilDeadline > 0);
        vm.assume(value <= 0);
        vm.assume(tokenId != 0);
        vm.expectRevert(InvoiceToken.InvoiceToken__AmountMustBeGreaterThanZero.selector);
        invoiceToken.mint(user, tokenId, value, timeUntilDeadline);
    }

    function testMintInvalidTokenId(uint256 value, uint256 timeUntilDeadline) public {
        vm.assume(timeUntilDeadline > 0);
        vm.assume(value > 0);
        vm.expectRevert(InvoiceToken.InvoiceToken__NotValidTokenId.selector);
        invoiceToken.mint(user, 0, value, timeUntilDeadline);
    }
}
