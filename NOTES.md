## SynthLend Outline

SynthEngine
    Borrower: 
        Deposits collateral (in ETH)
        Mints synthetic tokens (from available assets)
        Maintains a collateralization level above the minimum threshold to avoid liquidation

    Liquidator:
        Identifies an undercollateralized debt position
        Holds debt position asset (if not then some must be minted)
        Liquidates the undercollateralized debt position by paying off a part or all of the borrower's debt
        Receives portion of borrower's collateral plus liquidation bonus 
