// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SyntheticAsset.sol";

contract SynthEngine is ReentrancyGuard {

    // ---------- Errors --------------
    error SynthEngine__MintFailed();
    error SynthEngine__NeedsMoreThanZero();
    error SynthEngine__TransferFailed();
    error SynthEngine__BreaksHealthFactor(uint256 userHealthFactor);
    error SynthEngine__TokenAndPriceAddressesAmountsDontMatch;

    // ---------- Types --------------
    // using OracleFeed for AggregatorV3Interface; // OracleFeed is not defined

    // ---------- State Variables --------------
    SyntheticAsset private immutable synth;
    uint256 private constant MIN_HEALTH_FACTOR = 1; // Define your minimum health factor

    mapping(address => uint256) public balances; // Mapping user addresses to their balance
    mapping(address => address) private priceFeeds; // Mapping of token address to price feed address
    mapping(address => uint256) private synthMinted; // Mapping of user to amount of synthetic assets minted
    mapping(address => mapping(address => uint256)) private s_collateralDeposited; // Mapping of user to amount of collateral deposited

    // ---------- Events --------------
    event Minted(address indexed user, uint256 amount);
    event Burned(address indexed user, uint256 amount);
    event CollateralDeposited(address indexed user, address tokenCollateralAddress, uint256 amountCollateral);

    // ---------- Modifiers --------------
    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert SynthEngine__NeedsMoreThanZero();
        }
        _;
    }

    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddresses, address _synthAddress) {
        if(_tokenAddresses.length != _priceFeedAddresses.length){ 
            revert SynthEngine__TokenAndPriceAddressesAmountsDontMatch();
        }
        for(uint256 i = 0; i < _tokenAddresses.length; i++){
            priceFeeds[_tokenAddresses[i]] = _priceFeedAddresses[i];
        }
        synth = SyntheticAsset(_synthAddress);
    }

    function mintSynth(uint256 amountToMint) public moreThanZero(amountToMint) nonReentrant {
        synthMinted[msg.sender] += amountToMint;
        revertIfHealthFactorIsBroken(msg.sender);
        bool minted = synth.mint(msg.sender, amountToMint);

        if(minted != true){
            revert SynthEngine__MintFailed();
        }
    }

    function depositCollateralAndMint(address _tokenCollateralAddress, uint256 _collateralAmount, uint256 _amountToMint) public {
        depositCollateral(_tokenCollateralAddress, _collateralAmount);
        mintSynth(_amountToMint);
    }

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert SynthEngine__TransferFailed();
        }
    }

    function revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert SynthEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _healthFactor(address _user) internal view returns (uint256) {
       // TO DO
        return 0;
    }
}
