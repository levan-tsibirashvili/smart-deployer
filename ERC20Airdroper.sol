// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../IUtilityContract.sol";

/**
 * @title ERC1155Airdroper
 * @notice Distributes ERC1155 tokens from a treasury to multiple recipients.
 * @dev Designed to be used with the Clones (EIP-1167) factory pattern.
 */
contract ERC1155Airdroper is IUtilityContract, ReentrancyGuard {

    /**
     * @dev Restricts function access to the designated owner.
     */
    modifier onlyOwner(){
        if(msg.sender != owner) revert OnlyOwner(owner);
        _;
    }

    // --- State Variables ---

    IERC1155 public tokenAddress;     // The ERC1155 token contract address
    bool public initDone;             // Flag to prevent multiple initializations
    string public name;               // Internal name for the airdrop campaign
    address public treasuryAddress;   // The source address holding the tokens
    address public owner;             // The administrator of this specific clone

    /**
     * @notice Maps token IDs to the maximum amount allowed for transfer.
     * @dev Acts as a budget control to prevent over-spending from the treasury.
     */
    mapping(uint256 => uint256) public tokensForAirdrop;

    // --- Events ---

    /**
     * @dev Emitted when the proxy contract is successfully initialized.
     */
    event initialized(address indexed contractOwner, string name, address indexed contractAddress, uint256 timestamp);

    /**
     * @dev Emitted when a transfer is successful.
     */
    event transferSuccess(address indexed from, address indexed to, uint256 indexed tokenID, uint256 amount);

    /**
     * @dev Emitted when a transfer fails.
     */
    event transferFailed(address indexed to, uint256 indexed tokenID, uint256 amount);

    // --- Custom Errors ---

    error AlreadyInitialized();
    error ArraysLengthMismatch();
    error InvalidAmount();
    error IncorrectReceiver();
    error NotApproved();
    error OnlyOwner(address owner);

    /**
     * @notice Initializes the clone with campaign parameters.
     * @dev This function replaces the constructor for proxy-based deployments.
     * @param _initData Encoded data: (string name, address token, uint256[] ids, uint256[] amounts, address owner, address treasury).
     */
    function initialize(bytes memory _initData) external returns(bool) {
        if(initDone) revert AlreadyInitialized();

        (string memory _name, 
         address _tokenAddress, 
         uint256[] memory _ids, 
         uint256[] memory _amounts, 
         address _owner, 
         address _treasury) = abi.decode(_initData, (string, address, uint256[], uint256[], address, address));

        if(_amounts.length != _ids.length) revert ArraysLengthMismatch();

        tokenAddress = IERC1155(_tokenAddress);
        name = _name;
        treasuryAddress = _treasury;
        owner = _owner;

        // Set the budget/limit for each token ID
        for(uint256 i = 0; i < _ids.length; i++) {
            if(_amounts[i] == 0) revert InvalidAmount();
            tokensForAirdrop[_ids[i]] = _amounts[i];
        }

        initDone = true; 
        
        emit initialized(_owner, _name, address(this), block.timestamp);
        return true;
    }

    /**
     * @notice Executes the batch transfer of ERC1155 tokens to multiple receivers.
     * @dev Uses safeTransferFrom and handles failures within a try/catch block.
     */
    function airdropERC1155(address[] calldata _receivers, uint256[] calldata _ids, uint256[] calldata _amounts) external nonReentrant onlyOwner {
        IERC1155 _token = tokenAddress;
        address _treasury = treasuryAddress;

        uint256 len = _receivers.length;
        if (len != _ids.length || len != _amounts.length) revert ArraysLengthMismatch();
        
        if (!_token.isApprovedForAll(_treasury, address(this))) revert NotApproved();

        

        for (uint256 i = 0; i < len; ) {
            address to = _receivers[i];
            uint256 id = _ids[i];
            uint256 amount = _amounts[i];

            if (to == owner || to == _treasury) revert IncorrectReceiver();
            
            uint256 remaining = tokensForAirdrop[id];
            
            if (amount > remaining) revert InvalidAmount();
            
            try _token.safeTransferFrom(_treasury, to, id, amount, "") {
                unchecked {
                    tokensForAirdrop[id] = remaining - amount;
                }
                emit transferSuccess (_treasury, to, id, amount);
            } catch {
                emit transferFailed (to, id, amount);
            } 

            unchecked { ++i; }          
        }
    }

    /**
     * @notice Utility function to encode initialization data off-chain or on-chain.
     */
    function getInitData(
        string memory _name, 
        address _token, 
        uint256[] memory _ids, 
        uint256[] memory _amounts, 
        address _owner, 
        address _treasury
    ) external pure returns (bytes memory) {
        return abi.encode(_name, _token, _ids, _amounts, _owner, _treasury);
    }
}