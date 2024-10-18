import { LibDiamond } from  "../libraries/LibDiamond.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {MerkleProof} from "../libraries/MerkleProof.sol";

contract MerkleAirdropFacet {
    event AirdropClaimed(address indexed claimant, uint256 amount);

    function claimAirdrop(bytes32[] memory proof, uint256 amount) public {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        require(!ds.hasClaimed[msg.sender], "Address has already claimed");
    
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));
    
        require(MerkleProof.verify(proof, ds.merkleRoot, leaf), "Invalid proof");
    
        // Mark the address as claimed before transferring tokens
        ds.hasClaimed[msg.sender] = true;
    
        require(IERC20(address(this)).transfer(msg.sender, amount), "Token transfer failed");
        emit AirdropClaimed(msg.sender, amount);
    }
    
    function withdrawRemainingTokens() external {
        LibDiamond.enforceIsContractOwner();
        uint256 balance = IERC20(address(this)).balanceOf(address(this));
        require(IERC20(address(this)).transfer(LibDiamond.contractOwner(), balance), "Token transfer failed");
    }

    function setMerkleRoot(bytes32 _merkleRoot) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondStorage().merkleRoot = _merkleRoot;
    }
}