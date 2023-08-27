// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract CollateralManagement {

    error CollateralManagement__InsufficientCollateral();
    error CollateralManagement__InvalidOracleData();
    error CollateralManagement__InvalidDeposit();

    /// @dev Mapping of user to amount of ETH collateral deposited
    mapping(address => uint256) public collateralDeposited; 

    /// @dev Mapping of Chainlink pricefeeds of Synth to USD
    mapping(address => address) public assetToUsdPriceFeeds;

    event CollateralDeposited(address indexed user, uint256 collateralAmount);
    event CollateralRedeemed(address indexed user, uint256 collateralAmount);

    /*//////////////////////////////////////////////////////////////
                          Public Functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Allows deposits of ETH as collateral
    function depositCollateral() public payable {
        if (msg.value <= 0) {
            revert CollateralManagement__InvalidDeposit();
        }
        collateralDeposited[msg.sender] += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    /// @dev Allows redemtions of collateral
    function redeemCollateral(uint256 _amount, address user) public {
        if(collateralDeposited[user] < _amount) {
            revert CollateralManagement__InsufficientCollateral();
        }

        collateralDeposited[user] -= _amount;
        payable(user).transfer(_amount);
        emit CollateralRedeemed(user, _amount);
    }

    /**
     * @dev Returns the value of the user's collateral in USD.
     * 
     * The function calculates the value by fetching the latest price data for the `_synthAsset` and multiplying it with the user's collateral.
     * 
     * Requirements:
     * - The price data fetched from the oracle should be valid and not be a positive value.
     * 
     * @param _user The address of the user whose collateral value is to be determined.
     * @param _synthAsset The address of the synthetic asset for which the price is to be fetched.
     * @return The value of the user's collateral in USD.
     */
    function getCollateralValueInUsd(address _user, address _synthAsset) public view returns (uint256) {
        uint256 userCollateral = collateralDeposited[_user];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(assetToUsdPriceFeeds[_synthAsset]);
        (, int price, , , ) = priceFeed.latestRoundData();
        if (price <= 0){ 
            revert CollateralManagement__InvalidOracleData();
        }
        uint256 priceWithDecimals = uint256(price) * 10**10; // Confirm this
        return (userCollateral * priceWithDecimals) / 1e18;
    }


    
}
