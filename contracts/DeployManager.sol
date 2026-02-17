// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./ERC1155 Airdroper/ERC1155Airdroper.sol";
import "./ERC20 Airdroper/ERC20Airdroper.sol";
import "./IUtilityContract.sol";

contract DeployManager is Ownable {

    constructor() Ownable(msg.sender) {      }

    event NewContractAdded (string name, address _contractAddress, uint256 _fee, bool _isActive, uint256 _timestamp);
    event ContractFeeUpdated(address _contractAddress, uint256 _oldFee, uint256 _newFee, uint256 _timestamp);
    event ContractStatusUpdated (address _contractAddress, bool _isActive, uint256 _timestamp);
    event NewContractDeployed (address _daployer, address _contractAddress, uint256 _fee, uint256 _timestamp);

    error TransferFailed();
    error amountShouldBeMoreThenZERO();
    error recieverShouldNotBeAddressZERO();
    error notEnoughtFunds(uint256);
    error InvalidAddress();

    struct ContractInfo{
        string name;
        uint256 fee;
        bool isActive;
        uint256 registeredAt;
    }    
    mapping (address => ContractInfo)public contractsData;

    // deployer => deployed contract addresses
    mapping (address => address[]) public deployedContracts;

    function delpoy (address _contractAddress, bytes calldata _initData) external payable returns(address) {
        ContractInfo memory targContract = contractsData[_contractAddress];
        
        require(targContract.isActive, "contract is not active");
        require(msg.value >= targContract.fee, "not enought funds");
        require(targContract.registeredAt > 0, "contract does not exists");

        address cloneContractAddress = Clones.clone(_contractAddress);

        require(IUtilityContract(cloneContractAddress).initialize(_initData), "initialization failed");

        if(msg.value > targContract.fee){
            (bool success,) = payable(msg.sender).call{value: msg.value - targContract.fee}("");
            require(success, "transfer failed");
        }

        deployedContracts[msg.sender].push(cloneContractAddress);

        emit NewContractDeployed (msg.sender, cloneContractAddress, targContract.fee, block.timestamp);

        return cloneContractAddress;
    }

    function addNewContract (string calldata _name, address _contractAddress, uint256 _fee, bool _isActive) external onlyOwner {
        if(_contractAddress == address(0)) revert InvalidAddress();

        contractsData[_contractAddress] = ContractInfo({
            name: _name,
            fee: _fee, 
            isActive: _isActive,
            registeredAt: block.timestamp
        });

        emit NewContractAdded (_name, _contractAddress, _fee, _isActive, block.timestamp );
    }

    function updateFee (address _contractAddress, uint256 _newFee) external onlyOwner{
        require(contractsData[_contractAddress].registeredAt > 0, "contract does not exists");

        uint256 _oldFee = contractsData[_contractAddress].fee;
        contractsData[_contractAddress].fee = _newFee;

        emit ContractFeeUpdated(_contractAddress, _oldFee, _newFee, block.timestamp);
    }

    function deactivateContract (address _address) external onlyOwner{
        require(contractsData[_address].registeredAt > 0, "contract does not exists");

        contractsData[_address].isActive = false;

        emit ContractStatusUpdated (_address, false, block.timestamp);
    }

    function activateContract (address _address) external onlyOwner{
        require(contractsData[_address].registeredAt > 0, "contract does not exists");

        contractsData[_address].isActive = true;

        emit ContractStatusUpdated (_address, true, block.timestamp);
    }

    function withdraw (address payable _to, uint256 _amount) external onlyOwner {
        if (address(this).balance < _amount)revert notEnoughtFunds(address(this).balance);
        if (address(_to) == address(0)) revert recieverShouldNotBeAddressZERO();
        if(_amount <= 0) revert amountShouldBeMoreThenZERO();

        (bool success,) = _to.call{value: _amount}("");
        if(!success)revert TransferFailed();
    }
}