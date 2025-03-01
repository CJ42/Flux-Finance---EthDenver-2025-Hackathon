// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Modules
import {BaseHookReceiver} from "silo-core-v2/utils/hook-receivers/_common/BaseHookReceiver.sol";

// Libraries
import {Hook} from "silo-contracts-v2/silo-core/contracts/lib/Hook.sol";

//    .               .      _____ _      __  __                      .
//   .;;............ ..     |  ___| |_   _\ \/ /      .. ............;;.
// .;;;;::::::::::::..      | |_  | | | | |\  /       ..::::::::::::;;;;.
//  ':;;:::::::::::: . .    |  _| | | |_| |/  \      . . ::::::::::::;;:'
//    ':                    |_|   |_|\__,_/_/\_\                    :'

///
/// TODO: add GaugeHookReceiver + PartialLiquidation hook in inheritance + explain it is needed for production
contract FluXProtocol is BaseHookReceiver {
    function initialize(
        ISiloConfig _siloConfig,
        bytes calldata _data
    ) external override initialize {
        // Ensure hooks from any parent contracts are initialized

        // Initialize hook with SiloConfig address.
        // SiloConfig is the source of all information about Silo markets you are extending.
        BaseHookReceiver.__BaseHookReceiver_init(_siloConfig);
    }

    /// @inheritdoc IHookReceiver
    function hookReceiverConfig(
        address _silo
    ) external view override returns (uint24 hooksBerfore, uint24 hooksAfter) {
        // retrieve the current config of the parent hook
        (hooksBefore, hooksAfter) = super._hookReceiverConfig(_silo);

        // add additional hook to run before deposit
        hooksBefore = Hook.addAction(hooksAfter, Hook.DEPOSIT);
        _setHookConfig(nonBorrowableSiloCached, hooksBefore, hooksAfter);
    }

    /// @inheritdoc IHookReceiver
    /// @dev Check if some liquidity in the same pair provided for the recipient
    function afterAction(
        address /* _silo */,
        uint256 _action,
        bytes calldata _input
    ) external pure {
        if (Hook.matchAction(_action, Hook.DEPOSIT)) {
            // 1. check ChainLink data feed for price of ETH

            // 2. check for price range of Uniswap v4
            // TODO: find function for that in v4 codebase

            // TODO: re-allocate idle liquidity

            // extract the packed encoded calldata passed to `afterAction(address,uint256,bytes)`

            // bytes memory data = abi.encodePacked(_assets, _shares, _receiver, _exactAssets, _exactShare);
            (
                ,
                ,
                // uint256 assets
                // uint256 shares
                address receiver,
                uint256 receivedAssets, // uint256 mintedShares
                ,

            ) = Hook.afterDepositDecode(_input);

            //
        }
    }
}
