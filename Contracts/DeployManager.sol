// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./IUtilityContract.sol";

/**
 * @title DeployManager
 * @author YourName/ProjectName
 * @notice Manages registration and deployment of airdrop contract templates using EIP-1167 clones.
 * @dev This contract is gas-optimized and handles fee collection and refund logic.
 */
contract DeployManager is Ownable {

    /**
     * @dev Initializes the contract and sets the initial administrator.
     * @param initialOwner The address that will have administrative control.
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    // --- Events ---

    /**
     * @dev Emitted when a new implementation template is added.
     */
    event NewContractAdded(string name, address indexed _contractAddress, uint256 _fee, bool _isActive, uint256 _timestamp);
    
    /**
     * @dev Emitted when the service fee for a template is updated.
     */
    event ContractFeeUpdated(address indexed _contractAddress, uint256 _oldFee, uint256 _newFee, uint256 _timestamp);
    
    /**
     * @dev Emitted when a template is activated or deactivated.
     */
    event ContractStatusUpdated(address indexed _contractAddress, bool _isActive, uint256 _timestamp);
    
    /**
     * @dev Emitted when a user deploys a new airdrop proxy.
     */
    event NewContractDeployed(address indexed _deployer, address indexed _contractAddress, uint256 _fee, uint256 _timestamp);

    // --- Data Structures ---

    /**
     * @dev Struct to store metadata of a registered airdrop implementation.
     */
    struct ContractInfo {
        string name;            // Human-readable template name
        uint256 fee;            // Deployment fee in Wei
        bool isActive;          // Status of the template
        uint256 registeredAt;   // Registration block timestamp
    } 

    /// @notice Maps implementation (logic) address to its configuration metadata.
    mapping(address => ContractInfo) public contractsData;

    /// @notice Tracks all proxy contracts deployed by a specific user.
    mapping(address => address[]) public deployedContracts;

    // --- Custom Errors ---

    error ContractNotRegistered();
    error ContractNotActive();
    error TransferFailed();
    error AmountShouldBeMoreThanZERO();
    error ReceiverShouldNotBeAddressZERO();
    error NotEnoughFunds(uint256 required);
    error InvalidAddress();

    // --- Core Functions ---

    /**
     * @notice Deploys a gas-efficient clone of a registered airdrop template.
     * @dev Uses Clones.clone (EIP-1167) and calls initialize() on the new instance.
     * @param _contractAddress The implementation address to clone.
     * @param _initData ABI-encoded parameters for the initialization function.
     * @return cloneContractAddress The address of the newly created proxy.
     */
    function deploy(address _contractAddress, bytes calldata _initData) external payable returns(address) {
        ContractInfo memory targContract = contractsData[_contractAddress];

        // 1. Validation Checks
        if(targContract.registeredAt == 0) revert ContractNotRegistered();
        if(!targContract.isActive) revert ContractNotActive();
        
        // 2. Financial Validation
        if(msg.value < targContract.fee) revert NotEnoughFunds(targContract.fee);

        // 3. Deployment Logic
        address cloneContractAddress = Clones.clone(_contractAddress);

        // 4. Initialization (Replacing Constructor)
        IUtilityContract(cloneContractAddress).initialize(_initData);

        // 5. Excess ETH Refund (Safe Transfer)
        if(msg.value > targContract.fee){
            (bool success,) = payable(msg.sender).call{value: msg.value - targContract.fee}("");
            if(!success) revert TransferFailed();
        }

        // 6. Record Keeping
        deployedContracts[msg.sender].push(cloneContractAddress);

        emit NewContractDeployed(msg.sender, cloneContractAddress, targContract.fee, block.timestamp);

        return cloneContractAddress;
    }

    /**
     * @notice Registers a new implementation template.
     * @param _name Name of the template (e.g., "ERC20 Airdroper").
     * @param _contractAddress Logic contract address.
     * @param _fee Deployment cost in Wei.
     * @param _isActive Whether it's immediately available for use.
     */
    function addNewContract(string calldata _name, address _contractAddress, uint256 _fee, bool _isActive) external onlyOwner {
        if(_contractAddress == address(0)) revert InvalidAddress();

        contractsData[_contractAddress] = ContractInfo({
            name: _name,
            fee: _fee, 
            isActive: _isActive,
            registeredAt: block.timestamp
        });

        emit NewContractAdded(_name, _contractAddress, _fee, _isActive, block.timestamp);
    }

    /**
     * @notice Updates the service fee for a template.
     */
    function updateFee(address _contractAddress, uint256 _newFee) external onlyOwner {
        if(contractsData[_contractAddress].registeredAt == 0) revert ContractNotRegistered();

        uint256 _oldFee = contractsData[_contractAddress].fee;
        contractsData[_contractAddress].fee = _newFee;

        emit ContractFeeUpdated(_contractAddress, _oldFee, _newFee, block.timestamp);
    }

    /**
     * @notice Deactivates a template.
     */
    function deactivateContract(address _address) external onlyOwner {
        if(contractsData[_address].registeredAt == 0) revert ContractNotRegistered();
        contractsData[_address].isActive = false;
        emit ContractStatusUpdated(_address, false, block.timestamp);
    }

    /**
     * @notice Activates a previously deactivated template.
     */
    function activateContract(address _address) external onlyOwner {
        if(contractsData[_address].registeredAt == 0) revert ContractNotRegistered();
        contractsData[_address].isActive = true;
        emit ContractStatusUpdated(_address, true, block.timestamp);
    }

    /**
     * @notice Withdraws the accumulated fees from the manager.
     * @param _to Recipient address.
     * @param _amount Amount to withdraw in Wei.
     */
    function withdraw(address payable _to, uint256 _amount) external onlyOwner {
        if (address(this).balance < _amount) revert NotEnoughFunds(address(this).balance);
        if (address(_to) == address(0)) revert ReceiverShouldNotBeAddressZERO();
        if(_amount == 0) revert AmountShouldBeMoreThanZERO();

        (bool success,) = _to.call{value: _amount}("");
        if(!success) revert TransferFailed();
    }
}