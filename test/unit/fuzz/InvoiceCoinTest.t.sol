// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {InvoiceCoin} from "src/InvoiceCoin.sol";
import {Test} from "forge-std/Test.sol";

contract InvoiceCoinTest is Test {
    InvoiceCoin public invoiceCoin;
    address public owner = address(this);
    address public user = makeAddr("user");

    modifier minted() {
        invoiceCoin.mint(user, 100);
        _;
    }

    function setUp() public {
        invoiceCoin = new InvoiceCoin();
    }

    function testOnlyOwnerCanMint() public minted {
        assertEq(invoiceCoin.balanceOf(user), 100);
    }

    function testOnlyOwnerCanBurn(uint256 amount) public minted {
        vm.assume(amount <= 100);
        invoiceCoin.burn(user, amount);
        assertEq(invoiceCoin.balanceOf(user), 100 - amount);
    }

    function testCannotBurnMoreThanBalance(uint256 amount) public minted {
        vm.assume(amount > 100);
        vm.expectRevert();
        invoiceCoin.burn(user, amount);
    }

    function testNonOwnerCanNotMint(uint256 amount) public {
        vm.prank(user);
        vm.expectRevert();
        invoiceCoin.mint(user, amount);
    }

    function testNonOwnerCanNotBurn(uint256 amount) public minted {
        vm.prank(user);
        vm.expectRevert();
        invoiceCoin.burn(user, amount);
    }
}
