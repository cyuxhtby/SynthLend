// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../lib/openzeppelin-contracts.git/contracts/security/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts.git/contracts/interfaces/IERC20.sol";
import "./SyntheticAsset.sol";

contract SynthEngine is ReentrancyGuard {

    // ---------- Errors --------------
    error SynthEngine__MintFailed();
    error SynthEngine__NeedsMoreThanZero();
    error SynthEngine__TransferFailed();
    error SynthEngine__BreaksHealthFactor(uint256 userHealthFactor);
    error SynthEngine__TokenAmountsAndPriceAmountsDontMatch();

    // ---------- Types --------------

    // ---------- State Variables --------------
    SyntheticAsset private immutable i_synth;
    uint256 private constant MIN_HEALTH_FACTOR = 1; // Define your minimum health factor
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // Must be 200% over-collateralized

    mapping(address => uint256) public s_balances; // Mapping user addresses to their balance
    mapping(address => address) private s_priceFeeds; // Mapping of token address to price feed address
    mapping(address => uint256) private s_synthMinted; // Mapping of user to amount of synthetic assets minted
    mapping(address => mapping(address => uint256)) private s_collateralDeposited; // Mapping of user to amount of collateral deposited
    mapping(address => uint256) public s_totalCollateralDeposited; // Mapping of user to total collateral deposited


    // ---------- Events --------------
    event Minted(address indexed user, uint256 amount);
    event Burned(address indexed user, uint256 amount);
    event CollateralDeposited(address indexed user, address collateralAddress, uint256 collateralAmount);

    // ---------- Modifiers --------------
    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert SynthEngine__NeedsMoreThanZero();
        }
        _;
    }

    // ---------- Constructor --------------
    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddresses, address _synthAddress) {
        if(_tokenAddresses.length != _priceFeedAddresses.length){ 
            revert SynthEngine__TokenAmountsAndPriceAmountsDontMatch();
        }
        for(uint256 i = 0; i < _tokenAddresses.length; i++){
            s_priceFeeds[_tokenAddresses[i]] = _priceFeedAddresses[i];
        }
        i_synth = SyntheticAsset(_synthAddress);
    }

    // ---------- Public Functions --------------
    function mintSynth(uint256 _amountToMint) public moreThanZero(_amountToMint) nonReentrant {
        s_synthMinted[msg.sender] += _amountToMint;
        revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_synth.mint(msg.sender, _amountToMint);

        if(minted != true){
            revert SynthEngine__MintFailed();
        }
    }

    function depositCollateralAndMint(address _collateralAddress, uint256 _collateralAmount, uint256 _amountToMint) public {
        depositCollateral(_collateralAddress, _collateralAmount);
        mintSynth(_amountToMint);
    }

    // TO DO
    // Make external if nessisary
    function withdrawCollateral() public nonReentrant {}

    function burnSynth() public nonReentrant {}

    function liquidate() public nonReentrant {}

    // ---------- Internal Functions --------------


    // ---------- Private & Internal View & Pure Functions --------------
    function depositCollateral(address _collateralAddress, uint256 _collateralAmount) private moreThanZero(_collateralAmount) nonReentrant {
        uint256 collateralValueInUSD = _getTokenValueInUSD(_collateralAddress, _collateralAmount);
        s_collateralDeposited[msg.sender][_collateralAddress] += _collateralAmount;
        s_totalCollateralDeposited[msg.sender] += collateralValueInUSD;
        emit CollateralDeposited(msg.sender, _collateralAddress, _collateralAmount);
        bool successfulyTransfered = IERC20(_collateralAddress).transferFrom(msg.sender, address(this), _collateralAmount);
        if(!successfulyTransfered){
            revert SynthEngine__TransferFailed();
        }
    }

    function getAccountInformation(address user) private view returns (uint256 totalSynthMinted, uint256 totalCollateralDeposited){
        totalSynthMinted = s_synthMinted[user];
        totalCollateralDeposited = s_totalCollateralDeposited[user];
    }

    function revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert SynthEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _healthFactor(address user) private view returns (uint256) {
       (uint256 totalSynthMinted, uint256 totalCollateralDeposited) = getAccountInformation(user);
       return _calculateHealthFactor(totalSynthMinted, totalCollateralDeposited);
    }

    function _calculateHealthFactor(uint256 _totalSynthMinted, uint256 _totalCollateralDeposited) internal pure returns (uint256){
        // .max returns the max possible value of a uint256 in order to avoid a division by zero error
        if (_totalSynthMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (_totalCollateralDeposited * LIQUIDATION_THRESHOLD) / 100;
        return (collateralAdjustedForThreshold * 1e18) / _totalSynthMinted;
    }

    function _getTokenValueInUSD(address _tokenAddress, uint256 _amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_tokenAddress]);
        (,int price,,,) = priceFeed.latestRoundData();
        // 1 ETH = 1e18 WEI
        // price is returned with 10 trailing decimals of precision
        uint256 priceWithDecimals = uint256(price) * 10**10;
        return (_amount * priceWithDecimals) / 1e18;

    }
}
