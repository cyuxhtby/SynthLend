// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../lib/openzeppelin-contracts.git/contracts/security/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts.git/contracts/interfaces/IERC20.sol";
import "./SyntheticAsset.sol";

contract SynthEngine is ReentrancyGuard {
    // ---------- Errors --------------
    error SynthEngine__MintFailed();
    error SynthEngine__InsufficientCollateral();
    error SynthEngine__NeedsMoreThanZero();
    error SynthEngine__TransferFailed();
    error SynthEngine__BreaksHealthFactor(uint256 userHealthFactor);
    error SynthEngine__TokenAmountsAndPriceAmountsDontMatch();
    error SynthEngine__HealthFactorHealthy();
    error SynthEngine__InsufficientSynthToCoverDebt();
    error SynthEngine__ClaimedCollateralExceedsCollateralDeposited();

    // ---------- Types --------------

    // ---------- State Variables --------------
    SyntheticAsset private immutable synth;
    address[] private synthAssets; // List of offered synthetic assets
    uint256 private constant MIN_HEALTH_FACTOR = 1; // Define your minimum health factor
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // Must be 200% over-collateralized
    uint256 private constant LIQUIDATION_BONUS = 10; // 10% liquidation payout to incentivize protocol participants

    mapping(address => mapping(address => uint256)) private synthMinted; // Mapping of user to amount of synthetic assets minted per asset
    mapping(address => uint256) private collateralDeposited; // Mapping of user to amount of collateral deposited (only ETH)
    mapping(address => address) public priceFeeds; // Mapping of asset to priceFeed

    // ---------- Events --------------
    event Minted(address indexed user, uint256 amount);
    event Burned(address indexed user, uint256 amount);
    event CollateralDeposited(
        address indexed user,
        address collateralAddress,
        uint256 collateralAmount
    );
    event CollateralRedeemed(
        address indexed redeemFrom,
        address indexed redeenTo,
        uint256 collateralAmount
    );
    event Liquidated(
        address indexed user,
        address indexed liquidationFrom,
        uint256 amountBurned,
        uint256 collateralRedeemed
    );

    // ---------- Modifiers --------------
    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert SynthEngine__NeedsMoreThanZero();
        }
        _;
    }

    // ---------- Constructor --------------
    constructor(
        address[] memory _synthAssets,
        address[] memory _priceFeedAddresses,
        address _synthAddress
    ) {
        if (_synthAssets.length != _priceFeedAddresses.length) {
            revert SynthEngine__TokenAmountsAndPriceAmountsDontMatch();
        }
        for (uint256 i = 0; i < _synthAssets.length; i++) {
            priceFeeds[_synthAssets[i]] = _priceFeedAddresses[i];
            synthAssets.push(_synthAssets[i]);
        }
        synth = SyntheticAsset(_synthAddress);
    }

    // ---------- External Functions --------------
    function depositCollateralAndMintSynth(
        address _assetToMint,
        uint256 _amountToMint
    ) external payable {
        depositCollateral();
        mintSynth(_assetToMint, _amountToMint);
    }

    /*
     * @param _collateralAmount: The amount of collateral you're redeeming
     * @notice This function will redeem your collateral.
     * @notice If you have a synthAsset minted, you will not be able to redeem until you burn your synthAsset
     */
    function redeemCollateral(
        uint256 _amount
    ) external moreThanZero(_amount) nonReentrant {
        _redeemCollateral(_amount, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnSynth(
        uint256 _amount,
        address _synthAsset
    ) external nonReentrant {
        _burnSynth(_amount, msg.sender, _synthAsset, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function liquidate(
        address _user,
        uint256 _debtToCover,
        address _synthAsset
    ) external nonReentrant {
        uint256 userHealthFactor = _healthFactor(_user);
        if (userHealthFactor >= MIN_HEALTH_FACTOR) {
            revert SynthEngine__HealthFactorHealthy();
        }
        // Check if liquidator has enough synth to cover debt
        if (synthMinted[msg.sender][_synthAsset] < _debtToCover) {
            revert SynthEngine__InsufficientSynthToCoverDebt();
        }

        // Calculate collateral to claim based on the debt coverage and the liquidation bonus
        uint256 collateralValue = _getCollateralValueInUSD(
            priceFeeds[_synthAsset],
            collateralDeposited[_user]
        );

        uint256 collateralToClaim = (_debtToCover * collateralValue) /
            synthMinted[_user][_synthAsset];
        collateralToClaim =
            collateralToClaim +
            (collateralToClaim * LIQUIDATION_BONUS) /
            100;

        // Ensure that the claimed collateral doesn't exceed the user's deposited collateral
        if (collateralToClaim > collateralDeposited[_user]) {
            revert SynthEngine__ClaimedCollateralExceedsCollateralDeposited();
        }

        // Redeem the calculated amount of collateral
        _redeemCollateral(collateralToClaim, _user, msg.sender);

        // Burn liquidator's synthAsset
        _burnSynth(_debtToCover, msg.sender, _synthAsset, msg.sender);

        emit Liquidated(_user, msg.sender, _debtToCover, collateralToClaim);
    }

    // ---------- Public Functions --------------
    function depositCollateral() public payable moreThanZero(msg.value) {
        collateralDeposited[msg.sender] += msg.value;
    }

    function mintSynth(
        address _assetToMint,
        uint256 _amountToMint
    ) public moreThanZero(_amountToMint) nonReentrant {
        // Get the USD value of the asset to mint
        address assetToUsdPriceFeed = priceFeeds[_assetToMint];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            assetToUsdPriceFeed
        );
        (, int price, , , ) = priceFeed.latestRoundData();
        uint256 priceInUsd = uint256(price) * _amountToMint;
        // Check if user has enough collateral to mint the requested amount
        if (collateralDeposited[msg.sender] < priceInUsd) {
            revert SynthEngine__InsufficientCollateral();
        }
        // Update the amount of synthetic assets minted by the user
        synthMinted[msg.sender][_assetToMint] += _amountToMint;
        // Check if the user's position is still over-collateralized
        revertIfHealthFactorIsBroken(msg.sender);
        // Mint the synthetic assets
        bool minted = synth.mint(msg.sender, _amountToMint);
        // Ensure the minting was successful
        if (minted != true) {
            revert SynthEngine__MintFailed();
        }
    }

    // ---------- Internal Functions --------------

    // ---------- Private & Internal View & Pure Functions --------------

    function getAccountInformation(
        address _user
    )
        private
        view
        returns (
            uint256 totalSynthMintedInUsd,
            uint256 totalCollateralDeposited
        )
    {
        for (uint256 i = 0; i < synthAssets.length; i++) {
            uint256 assetAmount = synthMinted[_user][synthAssets[i]];
            uint256 assetValueInUsd = _getCollateralValueInUSD(
                priceFeeds[synthAssets[i]],
                assetAmount
            );
            totalSynthMintedInUsd += assetValueInUsd;
        }
        totalCollateralDeposited = collateralDeposited[_user];
    }

    function _getCollateralValueInUSD(
        address _assetToUsdPriceFeed,
        uint256 _amount
    ) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeeds[_assetToUsdPriceFeed]
        );
        (, int price, , , ) = priceFeed.latestRoundData();
        // 1 ETH = 1e18 WEI
        // price is returned with 10 trailing decimals of precision
        uint256 priceWithDecimals = uint256(price) * 10 ** 10;
        return (_amount * priceWithDecimals) / 1e18;
    }

    function _redeemCollateral(
        uint256 _collateralAmount,
        address _from,
        address _to
    ) private {
        collateralDeposited[_from] -= _collateralAmount;
        payable(_to).transfer(_collateralAmount);
        emit CollateralRedeemed(_from, _to, _collateralAmount);
    }

    function _burnSynth(
        uint256 _amount,
        address _onBehalfOf,
        address _synthAsset,
        address _synthFrom
    ) private {
        synthMinted[_onBehalfOf][_synthAsset] -= _amount;
        bool success = synth.transferFrom(_synthFrom, address(this), _amount);
        // This conditional is hypothetically unreachable since if transferFrom call fails, it will typically throw an error and revert the entire transaction
        if (!success) {
            revert SynthEngine__TransferFailed();
        }
        synth.burn(_amount);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (
            uint256 totalSynthMinted,
            uint256 totalCollateralDeposited
        ) = getAccountInformation(user);
        return
            _calculateHealthFactor(totalSynthMinted, totalCollateralDeposited);
    }

    function _calculateHealthFactor(
        uint256 _totalSynthMinted,
        uint256 _totalCollateralDeposited
    ) internal pure returns (uint256) {
        // .max returns the max possible value of a uint256 in order to avoid a division by zero error
        if (_totalSynthMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (_totalCollateralDeposited *
            LIQUIDATION_THRESHOLD) / 100;
        return (collateralAdjustedForThreshold * 1e18) / _totalSynthMinted;
    }

    function revertIfHealthFactorIsBroken(address _user) internal view {
        uint256 userHealthFactor = _healthFactor(_user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert SynthEngine__BreaksHealthFactor(userHealthFactor);
        }
    }
}
