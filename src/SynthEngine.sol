// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./CollateralManagement.sol";
import "./MintBurn.sol";
import "./Liquidation.sol";

contract SynthEngine {
    
    // Dependencies
    CollateralManagement public collateralManager;
    SynthMintBurn public synthManager;
    Liquidation public liquidator;

    // Constructor
    constructor(
        address _collateralManagerAddress,
        address _synthManagerAddress,
        address _liquidatorAddress
    ) {
        collateralManager = CollateralManagement(_collateralManagerAddress);
        synthManager = SynthMintBurn(_synthManagerAddress);
        liquidator = Liquidation(_liquidatorAddress);
    }

    // Public Functions
    function depositCollateralAndMintSynth(address _assetToMint, uint256 _amountToMint) external payable {
        collateralManager.depositCollateral{value: msg.value}();
        bool minted = synthManager.mintSynth(_assetToMint, _amountToMint, msg.sender, collateralManager.getCollateralDeposited(msg.sender));
        require(minted, "Minting failed due to insufficient collateral or other reasons.");
    }

    function redeemCollateral(uint256 _amount) external {
        bool redeemed = collateralManager.redeemCollateral(_amount, msg.sender);
        require(redeemed, "Redemption failed due to insufficient collateral or other reasons.");
    }

    function burnSynth(uint256 _amount, address _synthAsset) external {
        bool burned = synthManager.burnSynth(_amount, _synthAsset, msg.sender);
        require(burned, "Burn failed due to insufficient synth or other reasons.");
    }

    function executeLiquidation(address _user, uint256 _debtToCover, address _synthAsset) external {
        uint256 userHealthFactor = calculateHealthFactor(_user);
        bool liquidated = liquidator.liquidate(_user, _debtToCover, _synthAsset, userHealthFactor);
        require(liquidated, "Liquidation failed due to health factor, insufficient synth, or other reasons.");
    }

    // Private View Functions
    function calculateHealthFactor(address _user) private view returns (uint256) {
        uint256 totalSynthMinted = synthManager.getSynthMinted(_user, address(synthManager)); 
        uint256 totalCollateralDeposited = collateralManager.getCollateralDeposited(_user);
        return totalCollateralDeposited * 1e18 / totalSynthMinted;  // This is a simple health factor calculation. You can modify it based on your needs.
    }
}
