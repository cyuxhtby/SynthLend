// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import "../lib/forge-std/src/Test.sol";
import "../src/SyntheticAsset.sol";
import "../src/SynthEngine.sol";
import "../script/HelperConfig.s.sol";


contract SynthEngineTest is Test {

    SynthEngine public synthEngine;
    SyntheticAsset public synth;
    HelperConfig public helperConfig;

    address public xauUsdPriceFeed;
    address public wbtcUsdPriceFeed;
    address public jpyUsdPriceFeed;
    address public gbpUsdPriceFeed;
    address public wethUsdPriceFeed;
    address public usdcUsdPriceFeed;

    // TO DO: Build rest of test




}