// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./IUtilityContract.sol";

contract Airdroper_ERC1155 is IUtilityContract {
    // Proxy-ს შემთხვევაში ცვლადებს კონსტრუქტორში არ ვანიჭებთ მნიშვნელობას
    address public owner; 
    IERC1155 public tokenAddress;
    bool public initDone;
    string public contractName;

    mapping(uint256 => uint256) public leftedTokensForAirdrop;

    error NotOwner();
    error AlreadyInitialized();
    error ArraysLengthMismatch();
    error InvalidAmount();
    error ReceiverZeroAddress();
    error NotApproved();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function initialize(bytes memory _initData) external returns(bool) {
        if(initDone) revert AlreadyInitialized();

        (string memory _name, address _tokenAddress, uint256[] memory _ids, uint256[] memory _amounts, address _ownerAddress) = 
            abi.decode(_initData, (string, address, uint256[], uint256[], address));

        if(_amounts.length != _ids.length) revert ArraysLengthMismatch();
        if(_ownerAddress == address(0)) revert ReceiverZeroAddress();

        tokenAddress = IERC1155(_tokenAddress);
        contractName = _name;
        owner = _ownerAddress; // აქ ვნიშნავთ რეალურ მფლობელს

        for(uint256 i = 0; i < _ids.length; i++) {
            if(_amounts[i] == 0) revert InvalidAmount();
            leftedTokensForAirdrop[_ids[i]] = _amounts[i];
        }

        initDone = true; 
        return true;
    }

    function airdropERC1155(address[] calldata _receivers, uint256[] calldata _ids, uint256[] calldata _amounts) external onlyOwner {
        uint256 len = _receivers.length;
        if (len != _ids.length || len != _amounts.length) revert ArraysLengthMismatch();
        
        if (!tokenAddress.isApprovedForAll(msg.sender, address(this))) revert NotApproved();

        for (uint256 i = 0; i < len; i++) {
            address to = _receivers[i];
            uint256 id = _ids[i];
            uint256 amount = _amounts[i];

            if (to == address(0)) revert ReceiverZeroAddress();
            
            uint256 remaining = leftedTokensForAirdrop[id];
            if (amount > remaining) revert InvalidAmount();
            
            leftedTokensForAirdrop[id] = remaining - amount;

            tokenAddress.safeTransferFrom(msg.sender, to, id, amount, "");
        }
    }

    function getInitData(string memory _name, address _token, uint256[] memory _ids, uint256[] memory _amounts, address _owner) external pure returns (bytes memory) {
        return abi.encode(_name, _token, _ids, _amounts, _owner);
    }
}