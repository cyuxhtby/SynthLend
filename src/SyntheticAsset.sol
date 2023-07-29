// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

 import "../lib/forge-std/src/console2.sol";
 import "../lib/openzeppelin-contracts.git/contracts/token/ERC20/ERC20.sol";



contract SyntheticAsset is ERC20 {
    constructor() ERC20("Synthetic", "SYN") {
        
    }
    
    function mint(address caller, uint256 amountToMint) public returns (bool){
        _mint(caller, amountToMint);
        return true;
    }
   
    
}