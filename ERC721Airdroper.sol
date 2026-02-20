// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../IUtilityContract.sol";

/**
 * @title ERC20Airdroper
 * @notice Distributes ERC20 tokens from a treasury to multiple recipients.
 * @dev Designed to be used with the Clones (EIP-1167) factory pattern.
 */
contract ERC20Airdroper is IUtilityContract, ReentrancyGuard {

    /**
     * @dev Ensures that only the owner of this clone can call the function.
     */
    modifier onlyOwner(){
        if(msg.sender != owner) revert OnlyOwner(owner);
        _;
    }

    // --- State Variables ---

    IERC20 public tokenAddress;      // The ERC20 token contract interface
    bool public initDone;            // Prevents re-initialization
    string public name;              // Name of the airdrop campaign
    uint256 public amount;           // Total budget set during initialization
    address public treasuryAddress;  // The address holding the tokens
    address public owner;            // Administrator of this airdrop clone

    // --- Events ---

    /**
     * @dev Emitted when the proxy is successfully initialized.
     */
    event initialized(address indexed contractOwner, string name, address indexed contractAddress, uint256 timestamp);

    /**
     * @dev Emitted when a transfer is successful.
     */
    event transferSuccess(address indexed from, address indexed receiver); 

    /**
     * @dev Emitted when a transfer fails.
     */
    event transferFailed(address indexed receiver, uint256 amount);

    // --- Custom Errors ---

    error AlreadyInitialized();
    error ArraysLengthMismatch();
    error InvalidData();
    error NotEnoughApprovedTokens();
    error OnlyOwner(address owner);
    error IncorrectReceiver();

    /**
     * @notice Initializes the cloned contract with its logic.
     * @param _initData ABI encoded: (string name, address token, uint256 amount, address treasury, address owner).
     */
    function initialize(bytes memory _initData) external returns(bool) {
        if(initDone) revert AlreadyInitialized();

        (string memory _name, 
         address _tokenaddress, 
         uint256 _amount, 
         address _treasury, 
         address _owner) = abi.decode(_initData, (string, address, uint256, address, address));

        name = _name;
        tokenAddress = IERC20(_tokenaddress);
        amount = _amount; 
        treasuryAddress = _treasury;
        owner = _owner;
       
        initDone = true;

        emit initialized(_owner, _name, address(this), block.timestamp);
        return true;
    }

    /**
     * @notice Batch distributes ERC20 tokens to a list of receivers.
     * @param _receivers Array of destination addresses.
     * @param _amounts Array of token amounts to send.
     */
    function airdropERC20(address[] calldata _receivers, uint256[] calldata _amounts) external nonReentrant onlyOwner {
        uint256 len = _receivers.length;
        if(len != _amounts.length) revert ArraysLengthMismatch();

        // Local caching to save gas (prevents repeated storage reads)
        IERC20 _token = tokenAddress;
        address _treasury = treasuryAddress;

        

        for (uint256 i = 0; i < len; ) {
            address receiver = _receivers[i];
            uint256 amou = _amounts[i];

            if(receiver == address(0) || amou == 0) revert InvalidData();
            if(receiver == owner || receiver == _treasury) revert IncorrectReceiver();
            
            // Gas-efficient check: ensure the treasury has allowed the contract to spend
            if(_token.allowance(_treasury, address(this)) < amou) revert NotEnoughApprovedTokens();

            try _token.transferFrom(_treasury, receiver, amou) {
                emit transferSuccess(_treasury, receiver);
            } catch {
                emit transferFailed(receiver, amou);
            }

            // Using unchecked increment to save gas per iteration
            unchecked { ++i; }
        }       
    }

    /**
     * @notice Helper function to encode parameters for initialization.
     */
    function getInitData(
        string calldata _name, 
        address _tokenaddress, 
        uint256 _amount, 
        address _treasury, 
        address _owner
    ) external pure returns (bytes memory) {
        return abi.encode(_name, _tokenaddress, _amount, _treasury, _owner);
    }
}