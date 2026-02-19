// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../IUtilityContract.sol";

contract ERC721Airdroper is IUtilityContract, ReentrancyGuard {

    modifier onlyOwner () {
        if(msg.sender != owner) revert NotAnOwner(owner);
        _;
    }

    IERC721 public tokenAddress;
    bool public initDone;
    address public treasuryAddress;
    string public name;
    address public owner;

    // token id => if transfer posible
    mapping (uint256 => bool) public tokensForAirdrop;

    event transferSuccess (address from, address to, uint256 tokenID);
    event transferFailed (address to, uint256 tokenID);

    error AddressZero();
    error ContractAlreadyInitialized();
    error FirstApproveTokens();
    error ArrayLengthMismatch();
    error TokenDoesNotExists(uint256 tokenID);
    error NotAnOwner(address owner);

    function initialize (bytes memory _initData) external returns (bool) {
        if(initDone) revert ContractAlreadyInitialized();

        (string memory _name, address _tokenAddress, uint256 [] memory _tokenId, address _owner, address _treasury) = abi.decode(_initData, (string, address, uint256[], address , address));

        name = _name;
        tokenAddress = IERC721(_tokenAddress);
        treasuryAddress = _treasury;
        owner = _owner;

        for (uint256 i=0; i<_tokenId.length; i++) {
            tokensForAirdrop[_tokenId[i]] = true;
        }

        initDone = true;
        return true;
    }

    function ERC721Airdrop (address[] calldata _receivers, uint256[] calldata _ids) external nonReentrant onlyOwner {        
        uint256 len = _receivers.length;

        if(len != _ids.length) revert ArrayLengthMismatch();        
        if(!tokenAddress.isApprovedForAll(treasuryAddress, address(this))) revert FirstApproveTokens();

        for (uint256 i=0; i<len; i++){
            uint256 id = _ids[i];

            if(!tokensForAirdrop[id]) revert TokenDoesNotExists(id);
            address receiver = _receivers[i];

            try tokenAddress.safeTransferFrom(treasuryAddress, receiver, id){
                emit transferSuccess (treasuryAddress, receiver, id); 
                tokensForAirdrop[id] = false;
            } catch {
                emit transferFailed (receiver, id);
            }
        }
    }

    function getInitData (string calldata _name, address _tokenAddress, uint256 [] calldata _tokenId, address _owner, address _treasury) external pure returns (bytes memory){
        if(_tokenAddress == address(0) || _owner == address(0) || _treasury == address(0)) revert AddressZero();

        return abi.encode(_name, _tokenAddress, _tokenId, _owner, _treasury);
    }
}

/*

["1","2","3"]

["0xdD870fA1b7C4700F2BD7f44238821C26f7392148","0x583031D1113aD414F02576BD6afaBfb302140225","0xdD870fA1b7C4700F2BD7f44238821C26f7392148"]

*/