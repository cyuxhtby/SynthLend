// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./SyntheticAsset.sol";

contract SynthMintBurn {

    error SynthMint__InsufficientCollateral();
    error SynthBurn__InsufficientSynth();
    
    /// @dev ERC20 synthetic asset to mint or burn
    SyntheticAsset private immutable synth;

    /// @dev Mapping of user to amount of synthetic assets minted per asset
    mapping(address => mapping(address => uint256)) public synthMinted;

    /// @dev Mapping of asset to USD priceFeed
    mapping(address => address) public UsdPriceFeeds;  
    
    event Minted(address indexed user, uint256 amount);
    event Burned(address indexed user, uint256 amount);

    constructor(address _synthAddress) {
        synth = SyntheticAsset(_synthAddress);
    }

    /*//////////////////////////////////////////////////////////////
                          Public Functions 
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Mints a specified amount of synthetic asset for the user.
     * This function fetches the current USD price of the synthetic asset using Chainlink oracle.
     * It then checks if the user's collateral amount is sufficient to mint the desired amount of the synthetic asset.
     * If the collateral is sufficient, it updates the record of minted synthetic assets for the user and
     * mints the synthetic asset tokens to the user's address.
     * 
     * Requirements:
     * - The user must have enough collateral to cover the minted synthetic asset's value.
     * 
     * @param _assetToMint The address of the synthetic asset to be minted.
     * @param _amountToMint The amount of the synthetic asset to mint.
     * @param user The address of the user for whom the synthetic asset is being minted.
     * @param collateralAmount The amount of collateral the user has deposited.
     */
    function mintSynth(address _assetToMint, uint256 _amountToMint, address user, uint256 collateralAmount) public {
        address assetToUsdPriceFeed = UsdPriceFeeds[_assetToMint];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(assetToUsdPriceFeed);
        (, int price, , , ) = priceFeed.latestRoundData();
        uint256 priceInUsd = uint256(price) * _amountToMint;
        if (collateralAmount < priceInUsd) {
            revert SynthMint__InsufficientCollateral();
        }
        synthMinted[user][_assetToMint] += _amountToMint; 
        synth.mint(user, _amountToMint);
        
    }

    /**
     * @dev Burns a specified amount of `_synthAsset` from the `user`'s balance.
     * 
     * Requirements:
     * - The user must have more minted synth than what is being burned.
     * 
     * @param _amount The address of the synthetic asset to be burned.
     * @param _synthAsset The amount of the synthetic asset to burn.
     * @param user The address of the user for whom the synthetic asset is being burned.
     */
    function burnSynth(uint256 _amount, address _synthAsset, address user) public {
        if (_amount < synthMinted[user][_synthAsset]){
            revert SynthBurn__InsufficientSynth();
        }
        synthMinted[user][_synthAsset] -= _amount;
        synth.transferFrom(user, address(this), _amount);
        synth.burn(_amount);
    }

}

