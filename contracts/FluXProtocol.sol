// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Modules
import {BaseHookReceiver as SiloBaseHookReceiver} from "silo-core-v2/utils/hook-receivers/_common/BaseHookReceiver.sol";

// Interfaces
import {ISiloConfig} from "silo-core-v2/interfaces/ISiloConfig.sol";

// Libraries
import {Hook as SiloFinanceHook} from "silo-contracts-v2/silo-core/contracts/lib/Hook.sol";

//    .               .      _____ _      __  __                      .
//   .;;............ ..     |  ___| |_   _\ \/ /      .. ............;;.
// .;;;;::::::::::::..      | |_  | | | | |\  /       ..::::::::::::;;;;.
//  ':;;:::::::::::: . .    |  _| | | |_| |/  \      . . ::::::::::::;;:'
//    ':                    |_|   |_|\__,_/_/\_\                    :'

///
/// TODO: add GaugeHookReceiver + PartialLiquidation hook in inheritance + explain it is needed for production
abstract contract FluXProtocol is SiloBaseHookReceiver {
    function initialize(
        ISiloConfig _siloConfig,
        bytes calldata _data
    ) external override initializer {
        // Ensure hooks from any parent contracts are initialized

        // Initialize hook with SiloConfig address.
        // SiloConfig is the source of all information about Silo markets you are extending.
        SiloBaseHookReceiver.__BaseHookReceiver_init(_siloConfig);
    }

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
            SiloFinanceHook.addAction(hooksBefore, SiloFinanceHook.BORROW)
        );
    }

    /// @dev Check if some liquidity in the same pair provided for the recipient
    function beforeAction(
        address /* _silo */,
        uint256 _action,
        bytes calldata _input
    ) external pure {
        if (SiloFinanceHook.matchAction(_action, SiloFinanceHook.BORROW)) {
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
