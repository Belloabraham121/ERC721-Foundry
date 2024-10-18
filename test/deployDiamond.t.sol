// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/StakingFacet.sol";

import "../contracts/facets/ERC20Facet.sol";
import "../contracts/Diamond.sol";

import "./helpers/DiamondUtils.sol";
import "../contracts/facets/PresaleFacet.sol";
import "../contracts/facets/ERC721Facet.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC20Facet erc20Facet;
    StakingFacet stakingFacet;
    ERC721Facet erc721Facet;
    PresaleFacet presaleFacet;

    function testDeployDiamond() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet), "Test Token", "TST", 18);
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc20Facet = new ERC20Facet();
        presaleFacet = new PresaleFacet();
        erc721Facet = new ERC721Facet();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](5);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(erc20Facet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ERC20Facet")
            })
        );

        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(presaleFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectors("PresaleFacet")
        });

        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(erc721Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectors("ERC721Facet")
        });


        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
        
        
        string memory name = "Test Token";
        string memory symbol = "TST";
        uint8 decimals = 18;
        uint256 initialSupply = 1000000 * 10**uint256(decimals);

        // Check name
        assertEq(ERC20Facet(address(diamond)).name(), name);

        // Check symbol
        assertEq(ERC20Facet(address(diamond)).symbol(), symbol);

        // Check decimals
        assertEq(ERC20Facet(address(diamond)).decimals(), decimals);

        // Check total supply
        assertEq(ERC20Facet(address(diamond)).totalSupply(), 0);  // Initially, total supply should be 0

        // Check initial balance
        assertEq(ERC20Facet(address(diamond)).balanceOf(address(this)), 0);  // Initially, balance should be 0

        // Mint initial supply to this contract
        vm.prank(address(this));
        ERC20Facet(address(diamond)).mint(address(this), initialSupply);

        // Check updated total supply
        assertEq(ERC20Facet(address(diamond)).totalSupply(), initialSupply);

        // Check updated balance
        assertEq(ERC20Facet(address(diamond)).balanceOf(address(this)), initialSupply);

        // Test transfer
        address recipient = address(0x123);
        uint256 transferAmount = 1000 * 10**uint256(decimals);
        assertTrue(ERC20Facet(address(diamond)).transfer(recipient, transferAmount), "Transfer failed");
        assertEq(ERC20Facet(address(diamond)).balanceOf(recipient), transferAmount, "Incorrect recipient balance after transfer");
        assertEq(ERC20Facet(address(diamond)).balanceOf(address(this)), initialSupply - transferAmount, "Incorrect sender balance after transfer");

        // Test approve and transferFrom
        address spender = address(0x456);
        uint256 approvalAmount = 500 * 10**uint256(decimals);
        assertTrue(ERC20Facet(address(diamond)).approve(spender, approvalAmount), "Approval failed");
        assertEq(ERC20Facet(address(diamond)).allowance(address(this), spender), approvalAmount, "Incorrect allowance after approval");

        uint256 transferFromAmount = 250 * 10**uint256(decimals);
        vm.prank(spender);
        assertTrue(ERC20Facet(address(diamond)).transferFrom(address(this), recipient, transferFromAmount), "TransferFrom failed");
        assertEq(ERC20Facet(address(diamond)).balanceOf(recipient), transferAmount + transferFromAmount, "Incorrect recipient balance after transferFrom");
        assertEq(ERC20Facet(address(diamond)).balanceOf(address(this)), initialSupply - transferAmount - transferFromAmount, "Incorrect sender balance after transferFrom");
        assertEq(ERC20Facet(address(diamond)).allowance(address(this), spender), approvalAmount - transferFromAmount, "Incorrect allowance after transferFrom");

        vm.prank(owner);
        PresaleFacet(address(diamond)).setPresaleParameters(5 ether);

    }


    function testSetPresaleParameters() public {
        vm.prank(owner);
        PresaleFacet(address(diamond)).setPresaleParameters(10 ether);

        (uint256 price, uint256 minPurchase, uint256 maxPurchase) = PresaleFacet(address(diamond)).getPresaleInfo();
        assertEq(price, 1 ether);
        assertEq(minPurchase, 0.01 ether);
        assertEq(maxPurchase, 10 ether);
    }

    function testBuyPresaleMinimum() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        PresaleFacet(address(diamond)).buyPresale{value: 0.01 ether}();

        uint256 pieces = PresaleFacet(address(diamond)).getPresalePurchases(user1);
        assertEq(pieces, 0.3 ether / 1 ether * 30); // 0.3 pieces
    }

    function testBuyPresaleFullNFT() public {
        vm.deal(user1, 2 ether);
        vm.prank(user1);
        PresaleFacet(address(diamond)).buyPresale{value: 1 ether}();

        uint256 pieces = PresaleFacet(address(diamond)).getPresalePurchases(user1);
        assertEq(pieces, 30);

        uint256 balance = ERC721Facet(address(diamond)).balanceOf(user1);
        assertEq(balance, 1);
    }

    function testBuyPresaleMultipleNFTs() public {
        vm.deal(user1, 5 ether);
        vm.prank(user1);
        PresaleFacet(address(diamond)).buyPresale{value: 3.5 ether}();

        uint256 pieces = PresaleFacet(address(diamond)).getPresalePurchases(user1);
        assertEq(pieces, 105); // 3.5 * 30 = 105 pieces

        uint256 balance = ERC721Facet(address(diamond)).balanceOf(user1);
        assertEq(balance, 3); // 3 full NFTs
    }

    function testFailBuyPresaleBelowMinimum() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        PresaleFacet(address(diamond)).buyPresale{value: 0.009 ether}();
    }

    function testFailBuyPresaleAboveMaximum() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        PresaleFacet(address(diamond)).buyPresale{value: 6 ether}();
    }

    // Helper function to get function selectors from a contract
    function getSelectors(string memory _facetName) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }


    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}


}
