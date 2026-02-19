// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../IUtilityContract.sol";

contract ERC20Airdroper is IUtilityContract, ReentrancyGuard {

    modifier onlyOwner(){
        if(msg.sender != owner) revert OnlyOwner(owner);
        _;
    }


    IERC20 public tokenAddress;
    bool public initDone;
    string public name;
    uint256 public amount;
    address public treasuryAddress;
    address public owner;

    mapping(uint256 => uint256) public leftedTokensForAirdrop;

    error AlreadyInitialized();
    error ArraysLengthMismatch();
    error InvalidData();
    error NotEnoughApprovedTokens();
    error TokenTransferFailed();
    error OnlyOwner(address owner);

    function initialize(bytes memory _initData) external returns(bool) {
        if(initDone)revert AlreadyInitialized();

        (string memory _name, address _tokenaddress, uint256 _amount, address _treasury, address _owner) = abi.decode(_initData, (string, address, uint256, address, address));

        name = _name;
        tokenAddress = IERC20(_tokenaddress);
        amount = _amount; 
        treasuryAddress = _treasury;
        owner = _owner;
       
       initDone = true;
       return true;
    }

    function airdropERC20(address[] calldata _receivers, uint256[] calldata _amounts) external nonReentrant onlyOwner {
        if(_receivers.length != _amounts.length) revert ArraysLengthMismatch();
        if(tokenAddress.allowance(treasuryAddress, address(this)) < amount) revert NotEnoughApprovedTokens();

        for (uint256 i=0; i<_receivers.length; i++){
            if(_receivers[i] == address(0) || _amounts[i] <= 0) revert InvalidData();

            bool success = tokenAddress.transferFrom(treasuryAddress, _receivers[i], _amounts[i]);
            if(!success) revert TokenTransferFailed();
        }       
    }

    function getInitData(string calldata _name, address _tokenaddress, uint256 _amount, address _treasury, address _owner) external pure returns (bytes memory) {
        return abi.encode(_name, _tokenaddress, _amount, _treasury, _owner);
    }
    
}