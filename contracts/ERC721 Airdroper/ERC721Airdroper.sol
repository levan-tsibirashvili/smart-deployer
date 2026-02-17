// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../IUtilityContract.sol";

contract ERC721Airdroper is IUtilityContract, Ownable {

    constructor () Ownable(msg.sender) {}

    IERC721 public tokenAddress;
    bool public initDone;


    function initialize (bytes memory _initData) external returns (bool) {

    }









}

