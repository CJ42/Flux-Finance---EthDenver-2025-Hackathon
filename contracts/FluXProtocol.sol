// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Modules
import {BaseHookReceiver as SiloBaseHookReceiver} from "silo-core-v2/utils/hook-receivers/_common/BaseHookReceiver.sol";
import {BaseHook as UniswapV4BaseHook} from "uniswap-hooks/src/base/BaseHook.sol";

// Interfaces
import {ISiloConfig} from "silo-core-v2/interfaces/ISiloConfig.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager as IUniswapPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";

// Libraries
import {Hook as SiloFinanceHookLib} from "silo-contracts-v2/silo-core/contracts/lib/Hook.sol";
import {Hooks as UniswapV4HooksLib} from "v4-core/src/libraries/Hooks.sol";
import {Actions as UniswapActions} from "v4-periphery/src/libraries/Actions.sol";

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

/// @title FluXProtocol
/// @notice FluXProtocol is a hook contract that sits between a Uniswap v4 pool and a Silo Finance v2 lending pool.
/// It reacts to hooks from both pools on swaps and borrows.
abstract contract FluXProtocol is SiloBaseHookReceiver, UniswapV4BaseHook {
    // Hardcoded configurations for simplicity
    uint256 private constant _LIQUIDITY_AMOUNT_TO_MOVE = 5 ether;
    address private constant _USDC_TOKEN_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

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
        // move liquidity out of Uniswap 🦄
        // --------------------------------

        // 1. define the position manager for the Uniswap v4 pool (e.g: ETH / USDC)
        IUniswapPositionManager uniswapPositionManager = IPositionManager(
            0xcafecafecafecafecafecafecafecafecafecafe
        );

        // 2. encode action to remove liquidity in Uniswap
        bytes memory uniswapActions = abi.encodePacked(
            uint8(Actions.DECREASE_LIQUIDITY),
            uint8(Actions.TAKE_PAIR)
        );

        bytes[] memory params = new bytes[](2);

        // 🦄 Uniswap v4: DECREASE_LIQUIDITY action
        params[0] = abi.encode(
            111, // position identifier (example)
            _LIQUIDITY_AMOUNT_TO_MOVE, // amount of liquidity to remove
            0, // minimum amount of currency0 liquidity msg.sender is willing to receive
            0, // minimum amount of currency0 liquidity msg.sender is willing to receive
            "" // arbitrary data that will be forwarded to hook functions
        );

        Currency currency0 = Currency.wrap(address(0)); // address(0) for native ETH
        Currency currency1 = Currency.wrap(_USDC_TOKEN_ADDRESS);
        params[1] = abi.encode(currency0, currency1, _liquidityProvider);

        // move liquidity inside Silo Finance 🔲
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
