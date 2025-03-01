# Silo

- [] In Silo, what is the `hookReceiver`?

- Might do something after a `deposit` occurs.


## Learning

The hook receiver make calls on behalf of the Silo via `callOnBehalfOfSilo(...)`.

## The flow

**Scenario: Moving Idle Liquidity to Silo Lending**

The flow works as follow.

1. Alice has provided liquidity (10k) into a Uniswap v4 pool pair for USDC / wETH. She provided USDC for a specific price range.

2. The price moves out of range, so Alice's liquidity becomes idle in Uniswap pool.

3. Alice deposits more USDC into a lending protocol USDC / wETH in Silo Finance v2 (10k too).

4. The hook in the deposit function of Silo v2 is triggered:
    4.1 - it recognizes that liquidity is idle into Uniswap pool for Alice.
    4.2 - it moves the liquidity into the Silo lending market to earn interest.
    4.3 - it will take maybe 20 % as a hardcoded parameter to start.

<!-- Scenario: Rebalancing Back to Uniswap v4

 The liquidity remains in the lending pool until Uniswap v4 needs it again.

A swap in Uniswap v4 moves the price back into the LP range.
The Withdraw Function Hook is triggered, pulling the liquidity back from Silo into Uniswap.
The liquidity is now active for trading again. -->

We leverage here the **before deposit hook** function.

```solidity
    function deposit(
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        ISilo.CollateralType _collateralType
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        _hookCallBeforeDeposit(_collateralType, _assets, _shares, _receiver);

        ISiloConfig siloConfig = ShareTokenLib.siloConfig();

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));

        (
            address shareToken, address asset
        ) = siloConfig.getCollateralShareTokenAndAsset(address(this), _collateralType);

        (assets, shares) = SiloERC4626Lib.deposit({
            _token: asset,
            _depositor: msg.sender,
            _assets: _assets,
            _shares: _shares,
            _receiver: _receiver,
            _collateralShareToken: IShareToken(shareToken),
            _collateralType: _collateralType
        });

        siloConfig.turnOffReentrancyProtection();

        _hookCallAfterDeposit(_collateralType, _assets, _shares, _receiver, assets, shares);
    }

    // ...

    function _hookCallBeforeDeposit(
        ISilo.CollateralType _collateralType,
        uint256 _assets,
        uint256 _shares,
        address _receiver
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        uint256 action = Hook.depositAction(_collateralType);

        if (!_shareStorage.hookSetup.hooksBefore.matchAction(action)) return;

        bytes memory data = abi.encodePacked(_assets, _shares, _receiver);

        IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), action, data);
    }
```

/// @dev Hooks in the Silo protocol are very flexible/powerful.
/// They can be combined in multiple ways.
/// They run before/after each action in the Silo, which opens the possibility to execute a custom logic
/// whenever users interact with the Silo market.
/// You can extend Silo with a new functionality creating new methods via your custom hook.



