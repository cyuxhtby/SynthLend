// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig; // Renamed from activateNetworkConfig

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant XAU_USD_PRICE = 1550e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    int256 public constant JPY_USD_PRICE = 100e8;
    int256 public constant GPB_USD_PRICE = 80e8;
    int256 public constant USDC_USD_PRICE = 2000e8;

    struct NetworkConfig {
        address xauUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address jpyUsdPriceFeed;
        address gbpUsdPriceFeed;
        address wethUsdPriceFeed;
        address usdcUsdPriceFeed;
        uint256 deployerKey;
    }

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0x00; // Add value here
    
    constructor() {
        if (block.chainid == 11155111){
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            getOrCreateAnvilEthConfig(); 
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            xauUsdPriceFeed: 0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea,
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            jpyUsdPriceFeed: 0x8A6af2B75F23831ADc973ce6288e5329F63D86c6,
            gbpUsdPriceFeed: 0x91FAB41F5f3bE955963a986366edAcff1aaeaa83,
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            usdcUsdPriceFeed: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E,
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY // find this
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig){ 
        // Check to see if we set an active network config
        if (activeNetworkConfig.xauUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        
        vm.startBroadcast(); // Where we getting vm from tho ? 

        // Making all these mock tokens for no reason seems like
            
        // ETH
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);

        // XAU
        MockV3Aggregator xauUsdPriceFeed = new MockV3Aggregator(DECIMALS, XAU_USD_PRICE);
        ERC20Mock xauMock = new ERC20Mock("XAU", "XAU", msg.sender, 1000e8);

        // BTC
        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);

        // JPY
        MockV3Aggregator jpyUsdPriceFeed = new MockV3Aggregator(DECIMALS, JPY_USD_PRICE);
        ERC20Mock jpyMock = new ERC20Mock("JPY", "JPY", msg.sender, 1000e8);

        // GBP
        MockV3Aggregator gbpUsdPriceFeed = new MockV3Aggregator(DECIMALS, GPB_USD_PRICE);
        ERC20Mock gbpMock = new ERC20Mock("GBP", "GBP", msg.sender, 1000e8);

        // USDC
        MockV3Aggregator usdcUsdPriceFeed = new MockV3Aggregator(DECIMALS, USDC_USD_PRICE);
        ERC20Mock usdcMock = new ERC20Mock("USDC", "USDC", msg.sender, 1000e8);
        
        vm.stopBroadcast();

        activeNetworkConfig = NetworkConfig({
            xauUsdPriceFeed: address(xauUsdPriceFeed),
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            jpyUsdPriceFeed: address(jpyUsdPriceFeed),
            gbpUsdPriceFeed: address(gbpUsdPriceFeed),
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            usdcUsdPriceFeed: address(usdcUsdPriceFeed), 
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY 
        });
    }
}
