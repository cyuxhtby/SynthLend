// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

 import "../lib/forge-std/src/console2.sol";
 import "../lib/openzeppelin-contracts.git/contracts/token/ERC20/ERC20.sol";


contract SyntheticAsset is ERC20{
    address public owner;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    function mint(address to, uint256 amount) public onlyOwner returns(bool) {
        _mint(to, amount);
        return true;
    }

    function burn(uint256 amount) public returns(bool) {
        _burn(msg.sender, amount);
        return true;
    }
   
    
}