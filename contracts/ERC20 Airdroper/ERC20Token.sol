// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20Token is ERC20, Ownable {
    constructor()
        ERC20("Token", "TOK")
        Ownable(msg.sender)
    {
        _mint(owner(), 10000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}


/*

0x5B38Da6a701c568545dCfcB03FcB875f56beddC4  =>  10000000000000000000000
                                                3000000000000000000000

["0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB","0x617F2E2fD72FD9D5503197092aC168c91465E7f2","0x17F6AD8Ef982297579C203069C1DbfFE4348c372"]

["3000000000000000000000","3000000000000000000000","4000000000000000000000"]

*/