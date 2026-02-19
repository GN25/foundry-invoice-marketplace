// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.29;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract InvoiceToken is ERC721, Ownable {
    error InvoiceToken__InvalidTimeUntilDeadline();
    error InvoiceToken__AmountMustBeGreaterThanZero();
    error InvoiceToken__NotOwner();
    error InvoiceToken__NotValidTokenId();
    error InvoiceToken__TokenDoesNotExist();

    struct Invoice {
        uint256 id;
        uint256 value;
        uint256 timeUntilDeadline;
        bool isPaid;
    }

    uint256 private _invoiceId;
    mapping(uint256 id => Invoice invoice) public invoices;

    constructor() ERC721("InvoiceToken", "IT") Ownable(msg.sender) {}

    function mint(address to, uint256 tokenId, uint256 value, uint256 timeUntilDeadline) external onlyOwner {
        if (timeUntilDeadline <= 0) {
            revert InvoiceToken__InvalidTimeUntilDeadline();
        } else if (value <= 0) {
            revert InvoiceToken__AmountMustBeGreaterThanZero();
        } else if (invoices[tokenId].id != 0) {
            revert InvoiceToken__NotValidTokenId();
        } else if (tokenId == 0) {
            revert InvoiceToken__NotValidTokenId();
        }

        invoices[tokenId] = Invoice({id: tokenId, value: value, timeUntilDeadline: timeUntilDeadline, isPaid: false});

        _mint(to, tokenId);
    }

    function approve(address to, uint256 tokenId) public override {
        if (ownerOf(tokenId) != msg.sender) {
            revert InvoiceToken__NotOwner();
        }
        super.approve(to, tokenId);
    }

    function getInvoice(uint256 tokenId) external view returns (Invoice memory) {
        if (invoices[tokenId].id == 0) {
            revert InvoiceToken__TokenDoesNotExist();
        }
        return invoices[tokenId];
    }
}
