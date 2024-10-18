// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libraries/LibDiamond.sol";
import "./ERC721Facet.sol";

contract PresaleFacet {
    uint256 constant PIECES_PER_NFT = 30;
    uint256 constant MIN_PURCHASE_WEI = 0.01 ether;

    event PresalePurchase(address buyer, uint256 pieces);

    function setPresaleParameters(
        uint256 _maxPurchaseWei
    ) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.presalePrice = 1 ether; 
        ds.minPurchase = MIN_PURCHASE_WEI;
        ds.maxPurchase = _maxPurchaseWei;
    }

    function buyPresale() external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(msg.value >= ds.minPurchase, "Below minimum purchase amount");
        require(msg.value <= ds.maxPurchase, "Exceeds maximum purchase amount");

        uint256 piecesPurchased = (msg.value * PIECES_PER_NFT) / ds.presalePrice;
        require(piecesPurchased > 0, "Must purchase at least one piece");

        ds.presalePurchases[msg.sender] += piecesPurchased;
        ds.totalsupply += piecesPurchased;

       
        uint256 fullNFTs = piecesPurchased / PIECES_PER_NFT;
        for (uint256 i = 0; i < fullNFTs; i++) {
            ERC721Facet(address(this)).safeMint(msg.sender, ds.totalsupply - piecesPurchased + (i * PIECES_PER_NFT));
        }

        emit PresalePurchase(msg.sender, piecesPurchased);
    }

    function getPresalePurchases(address _buyer) external view returns (uint256) {
        return LibDiamond.diamondStorage().presalePurchases[_buyer];
    }

    function getPresaleInfo() external view returns (uint256 price, uint256 minPurchase, uint256 maxPurchase) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return (ds.presalePrice, ds.minPurchase, ds.maxPurchase);
    }
}