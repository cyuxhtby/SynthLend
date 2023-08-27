// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./SyntheticAsset.sol";

contract MintBurn {
    
    /// @dev ERC20 synthetic asset to mint or burn
    SyntheticAsset private immutable synth;

    /// @dev Mapping of user to amount of synthetic assets minted per asset
    mapping(address => mapping(address => uint256)) public synthMinted;

    /// @dev Mapping of asset to priceFeed
    mapping(address => address) public priceFeeds;  
    
    event Minted(address indexed user, uint256 amount);
    event Burned(address indexed user, uint256 amount);

    constructor(address _synthAddress) {
        synth = SyntheticAsset(_synthAddress);
    }

    /*//////////////////////////////////////////////////////////////
                          Public Functions 
    //////////////////////////////////////////////////////////////*/

    function mintSynth(address _assetToMint, uint256 _amountToMint, address user, uint256 collateralAmount) public returns (bool) {
        address assetToUsdPriceFeed = priceFeeds[_assetToMint];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(assetToUsdPriceFeed);
        (, int price, , , ) = priceFeed.latestRoundData();
        uint256 priceInUsd = uint256(price) * _amountToMint;

        if (collateralAmount < priceInUsd) {
            return false;  // Insufficient collateral
        }

        synthMinted[user][_assetToMint] += _amountToMint;

        bool minted = synth.mint(user, _amountToMint);
        return minted;
    }

    function burnSynth(uint256 _amount, address _synthAsset, address user) public returns (bool) {
        synthMinted[user][_synthAsset] -= _amount;
        bool success = synth.transferFrom(user, address(this), _amount);
        if (!success) {
            return false;  // Transfer failed
        }
        synth.burn(_amount);
        return true;
    }

    function getSynthMinted(address user, address _synthAsset) public view returns (uint256) {
        return synthMinted[user][_synthAsset];
    }

}

