// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Modules
import {BaseHookReceiver as SiloBaseHookReceiver} from "silo-core-v2/utils/hook-receivers/_common/BaseHookReceiver.sol";
import {BaseHook as UniswapV4BaseHook} from "uniswap-hooks/src/base/BaseHook.sol";

// Interfaces
import {ISiloConfig} from "silo-core-v2/interfaces/ISiloConfig.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

// Libraries
import {Hook as SiloFinanceHookLib} from "silo-contracts-v2/silo-core/contracts/lib/Hook.sol";
import {Hooks as UniswapV4HooksLib} from "v4-core/src/libraries/Hooks.sol";

// Constants
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";

//    .               .      _____ _      __  __                      .
//   .;;............ ..     |  ___| |_   _\ \/ /      .. ............;;.
// .;;;;::::::::::::..      | |_  | | | | |\  /       ..::::::::::::;;;;.
//  ':;;:::::::::::: . .    |  _| | | |_| |/  \      . . ::::::::::::;;:'
//    ':                    |_|   |_|\__,_/_/\_\                    :'

///
/// TODO: add GaugeHookReceiver + PartialLiquidation hook in inheritance + explain it is needed for production
abstract contract FluXProtocol is SiloBaseHookReceiver, UniswapV4BaseHook {
    address private _liquidityProvider;

    constructor(
        IPoolManager poolManager_,
        address liquidityProvider_
    ) UniswapV4BaseHook(poolManager_) {
        _liquidityProvider = liquidityProvider_;
    }

    function initialize(
        ISiloConfig _siloConfig,
        bytes calldata _data
    ) external override initializer {
        // Ensure hooks from any parent contracts are initialized

        // Initialize hook with SiloConfig address.
        // SiloConfig is the source of all information about Silo markets you are extending.
        SiloBaseHookReceiver.__BaseHookReceiver_init(_siloConfig);
    }

    /// @dev Uniswap v4 hook configurations
    /// Only configured before executing a swap to check if liquidity on Uniswap v4 pair is idle and move it
    function getHookPermissions()
        public
        pure
        override
        returns (UniswapV4HooksLib.Permissions memory)
    {
        return
            UniswapV4HooksLib.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    /// @dev SiloFinance v2 hook configurations
    function hookReceiverConfig(
        address _silo
    ) external view override returns (uint24 hooksBefore, uint24 hooksAfter) {
        // retrieve the current config of the parent hook
        // fetch current setup in case there were some hooks already implemented
        (hooksBefore, hooksAfter) = super._hookReceiverConfig(_silo);

        // add additional hook to run before borrowing action takes place
        // Use `addAction` as recommended to make sure we are not overriding other hooks' settings.
        // As the hooks bitmap store settings here for FluXProtocol + SiloBaseHookReceiver
        hooksBefore = uint24(
            SiloFinanceHookLib.addAction(hooksBefore, SiloFinanceHookLib.BORROW)
        );
    }

    /// @dev Check if the liquidity provided by user is idle (out of the price range configured)
    /// If it is the case, move the liquidity out of Uniswap v4 and provide it inside Silo Finance
    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        // beforeSwapCount[key.toId()]++;
        // return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        // move liquidity out of Uniswap
        // move liquidity inside Silo Finance
    }

    /// @dev Check if some liquidity in the same pair provided for the recipient
    function beforeAction(
        address /* _silo */,
        uint256 _action,
        bytes calldata _input
    ) external pure {
        if (
            SiloFinanceHookLib.matchAction(_action, SiloFinanceHookLib.BORROW)
        ) {
            // 1. check ChainLink data feed for price of ETH
            // 2. check for price range of Uniswap v4
            // TODO: find function for that in v4 codebase
            // TODO: re-allocate idle liquidity
            // extract the packed encoded calldata passed to `afterAction(address,uint256,bytes)`
            // bytes memory data = abi.encodePacked(_assets, _shares, _receiver, _exactAssets, _exactShare);
            // (
            //     ,
            //     ,
            //     // uint256 assets
            //     // uint256 shares
            //     address receiver,
            //     uint256 receivedAssets, // uint256 mintedShares
            //     ,
            // ) = SiloFinanceHook.afterDepositDecode(_input);
            //
        }
    }
}
