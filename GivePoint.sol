// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GivePoint is Ownable, ERC20{
    constructor() ERC20("GIVEPOINT_TEST", "GP"){
    }

    function mint( address user, uint amount ) external onlyOwner{
        super._mint(user, amount);
    }
}
