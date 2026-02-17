// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../IUtilityContract.sol";

contract ERC1155Airdroper is IUtilityContract, Ownable {

    constructor () Ownable(msg.sender) {}

    IERC1155 public tokenAddress;
    bool public initDone;
    string public contractName;
    address public treasuryAddress;

    mapping(uint256 => uint256) public leftedTokensForAirdrop;

    error NotOwner();
    error AlreadyInitialized();
    error ArraysLengthMismatch();
    error InvalidAmount();
    error ReceiverZeroAddress();
    error NotApproved();

    function initialize(bytes memory _initData) external returns(bool) {
        if(initDone) revert AlreadyInitialized();

        (string memory _name, address _tokenAddress, uint256[] memory _ids, uint256[] memory _amounts, address _owner, address _treasury) = 
            abi.decode(_initData, (string, address, uint256[], uint256[], address, address));

        if(_amounts.length != _ids.length) revert ArraysLengthMismatch();

        tokenAddress = IERC1155(_tokenAddress);
        contractName = _name;
        treasuryAddress = _treasury;
        Ownable.transferOwnership(_owner);

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
        
        if (!tokenAddress.isApprovedForAll(treasuryAddress, address(this))) revert NotApproved();

        for (uint256 i = 0; i < len; i++) {
            address to = _receivers[i];
            uint256 id = _ids[i];
            uint256 amount = _amounts[i];

            if (to == address(0)) revert ReceiverZeroAddress();
            
            uint256 remaining = leftedTokensForAirdrop[id];
            
            if (amount > remaining) revert InvalidAmount();
            
            leftedTokensForAirdrop[id] = remaining - amount;

            tokenAddress.safeTransferFrom(treasuryAddress, to, id, amount, "");
        }
    }

    function getInitData(string memory _name, address _token, uint256[] memory _ids, uint256[] memory _amounts, address _owner, address _treasury) external pure returns (bytes memory) {
        return abi.encode(_name, _token, _ids, _amounts, _owner, _treasury);
    }
}