// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "../lib/openzeppelin-contracts.git/contracts/security/ReentrancyGuard.sol";
import "./CollateralManagement.sol";
import "./SynthMintBurn.sol";
import "./Liquidation.sol";

contract SynthEngine is ReentrancyGuard{

    CollateralManagement public collateralManager;
    SynthMintBurn public synthManager;
    Liquidation public liquidator;

    constructor(
        address _collateralManagerAddress,
        address _synthManagerAddress,
        address _liquidatorAddress
    ) {
        collateralManager = CollateralManagement(_collateralManagerAddress);
        synthManager = SynthMintBurn(_synthManagerAddress);
        liquidator = Liquidation(_liquidatorAddress);
    }

   /*//////////////////////////////////////////////////////////////
                            External Functions
    //////////////////////////////////////////////////////////////*/

    function depositCollateralAndMintSynth(address _assetToMint, uint256 _amountToMint) external payable nonReentrant{
        collateralManager.depositCollateral{value: msg.value}();
        synthManager.mintSynth(_assetToMint, _amountToMint, msg.sender, collateralManager.collateralDeposited(msg.sender)); 
    }

    function redeemCollateral(uint256 _amount) external nonReentrant {
        collateralManager.redeemCollateral(_amount, msg.sender);
    }

    function burnSynth(uint256 _amount, address _synthAsset) external nonReentrant {
        synthManager.burnSynth(_amount, _synthAsset, msg.sender);
    }

    function executeLiquidation(address _user, uint256 _debtToCover, address _synthAsset) external nonReentrant {
        uint256 userHealthFactor = calculateHealthFactor(_user);
        liquidator.liquidate(_user, _debtToCover, _synthAsset, userHealthFactor);
    }

    /*//////////////////////////////////////////////////////////////
                            Private Function
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Calculates the health factor for a user.
     * The health factor is defined as the ratio of total collateral deposited by the user to the total synth minted by the user, scaled by 1e18.
     * This scaling ensures precision as Solidity does not support floating-point arithmetic.
     * 
     * @param _user The address of the user for whom the health factor is being calculated.
     * @return Returns the computed health factor for the user.
     */
    function calculateHealthFactor(address _user) private view returns (uint256) {
        uint256 totalSynthMinted = synthManager.getSynthMinted(_user, address(synthManager)); 
        uint256 totalCollateralDeposited = collateralManager.collateralDeposited(_user);
        return totalCollateralDeposited * 1e18 / totalSynthMinted; 
    }
}
