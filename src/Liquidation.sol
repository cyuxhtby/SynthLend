// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./CollateralManagement.sol";
import "./SynthMintBurn.sol";

contract Liquidation {

    error Liquidation__HealthFactorHealthy();
    error Liquidation__InsufficientSynthToCoverDebt();
    error Liquidation__ClaimedCollateralExceedsCollateralDeposited();
    error Liquidation__FailedToRedeemCollateral();
    error Liquidation__FailedToBurnSynth();

    CollateralManagement private collateralManager;
    SynthMintBurn private synthManager;
    
    /// @dev must be 200% over-collateralized
    uint256 private constant LIQUIDATION_THRESHOLD = 50; 

    /// @dev liquidation incentive
    uint256 private constant LIQUIDATION_BONUS = 10; 
    
    event Liquidated(address indexed user, address indexed liquidationFrom, uint256 amountBurned, uint256 collateralRedeemed);

    constructor(address _collateralManagerAddress, address _synthManagerAddress) {
        collateralManager = CollateralManagement(_collateralManagerAddress);
        synthManager = SynthMintBurn(_synthManagerAddress);
    }

    /*//////////////////////////////////////////////////////////////
                          Public Function
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Allows a user to liquidate another user's undercollateralized position.
     * 1. Checks if the user's position is eligible for liquidation based on their health factor.
     * 2. Validates that the caller has sufficient synth assets to cover the debt.
     * 3. Calculates the amount of collateral to claim based on the debt and the liquidation bonus.
     * 4. Redeems the collateral and burns the synth assets.
     * 
     * @param _user Address of the user whose position is being liquidated.
     * @param _debtToCover Amount of debt to cover in the liquidation.
     * @param _synthAsset Address of the synth asset involved in the liquidation.
     * @param userHealthFactor The health factor of the user's position.
     */
    function liquidate(address _user, uint256 _debtToCover, address _synthAsset, uint256 userHealthFactor) public {
        if (userHealthFactor >= LIQUIDATION_THRESHOLD) {
            revert Liquidation__HealthFactorHealthy();
        }

        if (synthManager.getSynthMinted(msg.sender, _synthAsset) < _debtToCover) {
            revert Liquidation__InsufficientSynthToCoverDebt();
        }

        uint256 collateralValueInUsd = collateralManager.getCollateralValueInUsd(_user, _synthAsset);

        uint256 collateralToClaim = (_debtToCover * collateralValueInUsd) / synthManager.getSynthMinted(_user, _synthAsset);
        collateralToClaim = collateralToClaim + (collateralToClaim * LIQUIDATION_BONUS) / 100;

        if (collateralToClaim > collateralManager.collateralDeposited(_user)) {
            revert Liquidation__ClaimedCollateralExceedsCollateralDeposited();
        }

        collateralManager.redeemCollateral(collateralToClaim, _user);

        synthManager.burnSynth(_debtToCover, _synthAsset, msg.sender);

        emit Liquidated(_user, msg.sender, _debtToCover, collateralToClaim);
    }
}
