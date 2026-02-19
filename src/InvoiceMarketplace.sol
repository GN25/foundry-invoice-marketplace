// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {InvoiceToken} from "src/InvoiceToken.sol";
import {InvoiceCoin} from "src/InvoiceCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title Invoice Marketplace
 * @author Guillem Navarra Paños (Github: @GN25)
 * @notice This is a simple implementation of an invoice marketplace where users can create invoices, deposit them as collateral to mint
 *  stablecoins and buy them with the stablecoins. The invoices are represented as NFTs and the stablecoins
 *  are represented as ERC20 tokens.
 * @notice This protocol does not profit from any fees, this is done on purpose to let users get the full value of their invoices.
 */
contract InvoiceMarketplace is ReentrancyGuard, IERC721Receiver {
    ////////////////////////////////////////////////////////////////////
    // Errors                                                         //
    ////////////////////////////////////////////////////////////////////

    error InvoiceMarketplace__NotEnoughCollateral();
    error InvoiceMarketplace__NotValidTokenId();
    error InvoiceMarketplace__NoInvoiceCoins();
    error InvoiceMarketplace__TokenNotOnSale();
    error InvoiceMarketplace__NotValidMinter();
    error InvoiceMarketplace__NotValidUser();

    ////////////////////////////////////////////////////////////////////
    // Events                                                         //
    ////////////////////////////////////////////////////////////////////

    event InvoiceCreated(uint256 indexed tokenId, uint256 indexed value, uint256 indexed timeUntilDeadline);
    event InvoiceDeposited(uint256 indexed tokenId, address indexed user, uint256 indexed collateralIncrease);
    event InvoiceBought(uint256 indexed tokenId, address indexed user);

    /////////////////////////////////////////////////////////////////////
    // State variables                                                 //
    /////////////////////////////////////////////////////////////////////

    InvoiceCoin public invoiceCoin;
    InvoiceToken public invoiceToken;

    uint256 public constant RISK_FACTOR = 90;
    uint256 public constant RISK_PRECISION = 100;

    address public immutable i_minter;

    mapping(address user => uint256 collateralAllowed) public collateralAllowed;

    /**
     *
     * @param _invoiceCoin the address of the InvoiceCoin contract. This contract is used to mint and burn the stablecoin that is used to buy the invoices and as collateral for minting more stablecoins.
     * @param _invoiceToken the address of the InvoiceToken contract. This contract is used to mint and transfer the NFTs that represent the invoices.
     */
    constructor(address _invoiceCoin, address _invoiceToken, address _minter) {
        invoiceCoin = InvoiceCoin(_invoiceCoin);
        invoiceToken = InvoiceToken(_invoiceToken);
        i_minter = _minter;
    }

    ////////////////////////////////////////////////////////////////////////
    // External functions                                                 //
    ////////////////////////////////////////////////////////////////////////

    /**
     *
     * @param to owner of the invoice to be created
     * @param tokenId id of the token of the invoice (chosen by the user, but must be unique)
     * @param value value in USD of the invoice
     * @param timeUntilDeadline time until the invoice is due, in seconds. Must be greater than 0.
     * //TODO: Right now, only the owner can create invoices but in the future this could be performed
     * by a decentralized oracle that verifies the existence and validity of the invoice in an external system
     */
    function createInvoice(address to, uint256 tokenId, uint256 value, uint256 timeUntilDeadline) external {
        if (tokenId == 0) {
            revert InvoiceMarketplace__NotValidTokenId();
        } else if (msg.sender != i_minter) {
            revert InvoiceMarketplace__NotValidMinter();
        }
        invoiceToken.mint(to, tokenId, value, timeUntilDeadline);
        emit InvoiceCreated(tokenId, value, timeUntilDeadline);
    }

    function depositInvoiceAndMintCollateral(uint256 tokenId) external nonReentrant {
        _depositInvoice(tokenId);
        uint256 collateralIncrease = _getCollateralValue(tokenId);
        _mintCollateral(msg.sender, collateralIncrease);
        emit InvoiceDeposited(tokenId, msg.sender, collateralIncrease);
    }

    function depositInvoice(uint256 tokenId) external {
        _depositInvoice(tokenId);
        emit InvoiceDeposited(tokenId, msg.sender, _getCollateralValue(tokenId));
    }

    function mintCollateral(address user, uint256 amount) public {
        if (user != msg.sender) {
            revert InvoiceMarketplace__NotValidUser();
        }
        _mintCollateral(user, amount);
    }

    function buyInvoice(uint256 tokenId) external {
        if (invoiceCoin.balanceOf(msg.sender) < _getCollateralValue(tokenId)) {
            revert InvoiceMarketplace__NoInvoiceCoins();
        }
        if (invoiceToken.ownerOf(tokenId) != address(this)) {
            revert InvoiceMarketplace__TokenNotOnSale();
        }
        invoiceCoin.burn(msg.sender, _getCollateralValue(tokenId));
        invoiceToken.safeTransferFrom(address(this), msg.sender, tokenId);
        emit InvoiceBought(tokenId, msg.sender);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    ////////////////////////////////////////////////////////////////////////
    // Internal functions                                                 //
    ////////////////////////////////////////////////////////////////////////

    function _depositInvoice(uint256 tokenId) internal {
        invoiceToken.safeTransferFrom(msg.sender, address(this), tokenId);
        uint256 collateralIncrease = _getCollateralValue(tokenId);
        collateralAllowed[msg.sender] += collateralIncrease;
    }

    function _getCollateralValue(uint256 tokenId) internal view returns (uint256) {
        InvoiceToken.Invoice memory invoice = invoiceToken.getInvoice(tokenId);
        return (invoice.value * RISK_FACTOR) / RISK_PRECISION;
    }

    function _mintCollateral(address user, uint256 amount) internal {
        if (collateralAllowed[user] < amount) {
            revert InvoiceMarketplace__NotEnoughCollateral();
        } else if (amount == 0) {
            revert InvoiceMarketplace__NoInvoiceCoins();
        }
        collateralAllowed[user] -= amount;
        invoiceCoin.mint(user, amount);
    }
}
