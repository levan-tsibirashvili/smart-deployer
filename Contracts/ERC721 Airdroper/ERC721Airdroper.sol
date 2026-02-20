// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../IUtilityContract.sol";

/**
 * @title ERC721Airdroper
 * @notice Distributes specific ERC721 (NFT) tokens from a treasury to recipients.
 * @dev Designed to be deployed as a minimal proxy clone via DeployManager.
 */
contract ERC721Airdroper is IUtilityContract, ReentrancyGuard {

    /**
     * @dev Restricts access to the contract owner.
     */
    modifier onlyOwner () {
        if(msg.sender != owner) revert NotAnOwner(owner);
        _;
    }

    // --- State Variables ---

    IERC721 public tokenAddress;      // The ERC721 NFT contract address
    bool public initDone;             // Prevents re-initialization
    address public treasuryAddress;   // The address holding the NFTs
    string public name;               // Name of the airdrop campaign
    address public owner;             // Administrator of this airdrop clone

    /**
     * @notice Maps token ID to a boolean indicating if it is registered for this airdrop.
     * @dev Ensures only pre-approved NFT IDs can be sent through this contract.
     */
    mapping (uint256 => bool) public tokensForAirdrop;

    // --- Events ---

    /**
     * @dev Emitted when the proxy contract is successfully initialized.
     */
    event initialized(address indexed contractOwner, string name, address indexed contractAddress, uint256 timestamp);

    /**
     * @dev Emitted when an NFT transfer is successful.
     */
    event transferSuccess (address indexed from, address indexed to, uint256 indexed tokenID);

    /**
     * @dev Emitted when an NFT transfer fails.
     */
    event transferFailed (address indexed to, uint256 indexed tokenID);

    // --- Custom Errors ---

    error AddressZero();
    error ContractAlreadyInitialized();
    error FirstApproveTokens();
    error ArrayLengthMismatch();
    error TokenDoesNotExists(uint256 tokenID);
    error NotAnOwner(address owner);
    error IncorrectReveiver();

    /**
     * @notice Initializes the clone with campaign parameters.
     * @dev Sets budget limits for specific NFT IDs.
     * @param _initData Encoded data: (string name, address token, uint256[] ids, address owner, address treasury).
     */
    function initialize (bytes memory _initData) external returns (bool) {
        if(initDone) revert ContractAlreadyInitialized();

        (string memory _name, 
         address _tokenAddress, 
         uint256[] memory _tokenId, 
         address _owner, 
         address _treasury) = abi.decode(_initData, (string, address, uint256[], address , address));

        name = _name;
        tokenAddress = IERC721(_tokenAddress);
        treasuryAddress = _treasury;
        owner = _owner;

        // Register allowed token IDs for this airdrop
        for (uint256 i = 0; i < _tokenId.length; ) {
            tokensForAirdrop[_tokenId[i]] = true;
            unchecked { ++i; }
        }

        initDone = true;

        emit initialized(_owner, _name, address(this), block.timestamp);
        return true;
    }

    /**
     * @notice Distributes NFTs to a batch of recipients.
     * @dev Uses safeTransferFrom. Each NFT ID must be registered in tokensForAirdrop.
     * @param _receivers Array of recipient addresses.
     * @param _ids Array of unique NFT IDs to transfer.
     */
    function ERC721Airdrop (address[] calldata _receivers, uint256[] calldata _ids) external nonReentrant onlyOwner {        
        uint256 len = _receivers.length;
        if(len != _ids.length) revert ArrayLengthMismatch();

        // Local caching to save gas on repeated storage reads
        IERC721 _token = tokenAddress;
        address _treasury = treasuryAddress;
        
        // Standard ERC721 approval check
        if(!_token.isApprovedForAll(_treasury, address(this))) revert FirstApproveTokens();

        

        for (uint256 i = 0; i < len; ){
            uint256 id = _ids[i];
            address receiver = _receivers[i];

            // Security checks
            if(!tokensForAirdrop[id]) revert TokenDoesNotExists(id);
            if(receiver == _treasury || receiver == owner) revert IncorrectReveiver();

            try _token.safeTransferFrom(_treasury, receiver, id){
                // Disable the ID in the budget mapping after successful transfer
                tokensForAirdrop[id] = false;
                emit transferSuccess (_treasury, receiver, id); 
            } catch {
                emit transferFailed (receiver, id);
            }

            // Gas-optimized increment
            unchecked { ++i; }
        }
    }

    /**
     * @notice Helper function to encode initialization parameters.
     * @dev Also includes basic address(0) validation.
     */
    function getInitData (
        string calldata _name, 
        address _tokenAddress, 
        uint256 [] calldata _tokenId, 
        address _owner, 
        address _treasury
    ) external pure returns (bytes memory){
        if(_tokenAddress == address(0) || _owner == address(0) || _treasury == address(0)) revert AddressZero();

        return abi.encode(_name, _tokenAddress, _tokenId, _owner, _treasury);
    }
}