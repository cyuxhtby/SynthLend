// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "../../lib/forge-std/src/Test.sol";
import "../../src/SyntheticAsset.sol";
import "../../src/SynthEngine.sol";
import "../mocks/MockV3Aggregator.sol";
import "../mocks/ERC20Mock.sol";

contract SynthEngineTest is Test {

    MockV3Aggregator priceFeed;
    SynthEngine engine;
    ERC20Mock synthMock;

    uint256 private constant INITIAL_SUPPLY = 1000000 * 10 ** 18; // 1 million tokens
    int256 private constant INITIAL_PRICE = 1000; // Mock price of $1000

    function setUp() public {
        synthMock = new ERC20Mock("MockAsset", "MOCK", address(this), INITIAL_SUPPLY);
        
        // Deploy the mock price feed with 8 decimals.
        priceFeed = new MockV3Aggregator(8, INITIAL_PRICE);

        address[] memory assets = new address[](1);
        address[] memory feeds = new address[](1);
        assets[0] = address(synthMock);
        feeds[0] = address(priceFeed);

        engine = new SynthEngine(assets, feeds, address(synthMock));
    }

    function test_mintSynth() public {
        int price = 2000 * 10**8;  // Mocking a price increase to $2000 with 8 decimals
        priceFeed.updateAnswer(price);

        uint256 amount_to_mint = 1 ether;
        engine.mintSynth(address(synthMock), amount_to_mint);

        // Assert the minted amount
        assertEq(engine.synthMinted(address(this), address(synthMock)), amount_to_mint);

    }

    function testFail_insufficientCollateral() public {
        // This test will attempt to mint a large amount without updating the price feed,
        // leading to insufficient collateral and a revert.
        uint256 large_amount_to_mint = 1000 ether;
        engine.mintSynth(address(synthMock), large_amount_to_mint);
    }
}
