// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

contract Greeter {
    string public greeting;

    function setGreeting(string memory _greeting) public {
        greeting = _greeting;
    }

    function getGreeting() public view returns(string memory){
        return greeting;
    }
}