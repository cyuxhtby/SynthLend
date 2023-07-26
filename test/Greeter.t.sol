// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Greeter} from "../src/Greeter.sol";

contract GreeterTest is Test { 
    Greeter public greeting;

    function setUp() public {
        greeting = new Greeter();
        greeting.setGreeting("Hey...");
    }

    // Functions prefixed with `test` are run as a test case
    function test_GreetingIsHey() public {
        assertEq(greeting.getGreeting(), "Hey...");
    }

    // testFail - inverse of the test prefix - if the function does not revert, the test fails.
    function testFail_GreetingIsYuh() public {
        assertEq(greeting.getGreeting(), "Yuh");
    }

}