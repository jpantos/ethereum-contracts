// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {PantosTypes} from "../../src/interfaces/PantosTypes.sol";
import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosToken} from "../../src/PantosToken.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {AccessController} from "../../src/access/AccessController.sol";

import {PantosHubDeployer} from "../helpers/PantosHubDeployer.s.sol";

abstract contract PantosHubRedeployer is PantosHubDeployer {
    bool private _initialized;
    /// @dev Mapping of BlockchainId enum to map of tokens to external tokens addresses
    mapping(address => mapping(BlockchainId => PantosTypes.ExternalTokenRecord))
        private _ownedToExternalTokens;
    PantosToken[] private _ownedTokens;
    IPantosHub private _oldPantosHub;
    PantosToken private _pantosToken;

    modifier onlyPantosHubRedeployerInitialized() {
        require(_initialized, "PantosHubRedeployer: not initialized");
        _;
    }

    function initializePantosHubRedeployer(IPantosHub oldPantosHub) public {
        _initialized = true;
        _oldPantosHub = oldPantosHub;
        _pantosToken = PantosToken(_oldPantosHub.getPantosToken());
        readOwnedAndExternalTokensFromOldPantosHub(_oldPantosHub);
    }

    function readOwnedAndExternalTokensFromOldPantosHub(
        IPantosHub pantosHubProxy
    ) private {
        Blockchain memory blockchain = determineBlockchain();
        address[] memory tokens = pantosHubProxy.getTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            PantosToken token = PantosToken(tokens[i]);
            if (token.owner() == msg.sender) {
                console2.log("adding %s to owned tokens", token.symbol());
                _ownedTokens.push(token);
                for (
                    uint256 blockchainId;
                    blockchainId < getBlockchainsLength();
                    blockchainId++
                ) {
                    Blockchain memory otherBlockchain = getBlockchainById(
                        BlockchainId(blockchainId)
                    );
                    if (
                        otherBlockchain.blockchainId !=
                        blockchain.blockchainId &&
                        !otherBlockchain.skip
                    ) {
                        PantosTypes.ExternalTokenRecord
                            memory externalTokenRecord = pantosHubProxy
                                .getExternalTokenRecord(
                                    tokens[i],
                                    blockchainId
                                );
                        _ownedToExternalTokens[tokens[i]][
                            BlockchainId(blockchainId)
                        ] = externalTokenRecord;
                    }
                }
            } else {
                console2.log(
                    "skipped adding %s to owned tokens; owner: %s;"
                    " address: %s",
                    token.symbol(),
                    token.owner(),
                    address(token)
                );
            }
        }
    }

    function migrateTokensFromOldHubToNewHub(
        IPantosHub newPantosHub
    ) public onlyPantosHubRedeployerInitialized {
        console2.log(
            "Migrating %d tokens from the old PantosHub to the new one",
            _ownedTokens.length
        );

        for (uint256 i = 0; i < _ownedTokens.length; i++) {
            if (address(_ownedTokens[i]) != address(_pantosToken)) {
                registerTokenAtNewHub(newPantosHub, _ownedTokens[i]);
            }
            for (
                uint256 blockchainId;
                blockchainId < getBlockchainsLength();
                blockchainId++
            ) {
                Blockchain memory blockchain = getBlockchainById(
                    BlockchainId(blockchainId)
                );
                if (!blockchain.skip) {
                    PantosTypes.ExternalTokenRecord
                        memory externalTokenRecord = _ownedToExternalTokens[
                            address(_ownedTokens[i])
                        ][BlockchainId(blockchainId)];
                    if (externalTokenRecord.active) {
                        registerExternalTokenAtNewHub(
                            newPantosHub,
                            _ownedTokens[i],
                            blockchainId,
                            externalTokenRecord.externalToken
                        );
                    }
                }
            }
        }
        // unregister tokens from old hub after all registered at new hub
        unregisterTokensFromOldHub();
    }

    function registerTokenAtNewHub(
        IPantosHub newPantosHub,
        PantosToken token
    ) public onlyPantosHubRedeployerInitialized {
        PantosTypes.TokenRecord memory tokenRecord = newPantosHub
            .getTokenRecord(address(token));
        if (!tokenRecord.active) {
            newPantosHub.registerToken(address(token));
            console2.log("New PantosHub.registerToken(%s)", address(token));
        } else {
            console2.log(
                "Token already registered; skipping registerToken(%s)",
                address(token)
            );
        }
    }

    function registerExternalTokenAtNewHub(
        IPantosHub newPantosHub,
        PantosToken token,
        uint256 blockchainId,
        string memory externalToken
    ) public onlyPantosHubRedeployerInitialized {
        PantosTypes.ExternalTokenRecord
            memory externalTokenRecord = newPantosHub.getExternalTokenRecord(
                address(token),
                blockchainId
            );

        if (!externalTokenRecord.active) {
            newPantosHub.registerExternalToken(
                address(token),
                blockchainId,
                externalToken
            );
            console2.log(
                "New PantosHub.registerExternalToken(%s, %d, %s)",
                address(token),
                blockchainId,
                externalToken
            );
        } else {
            console2.log(
                "External token already registered;"
                "skipping PantosHub.registerExternalToken(%s, %d, %s)",
                address(token),
                blockchainId,
                externalToken
            );
        }
    }

    function unregisterTokensFromOldHub()
        public
        onlyPantosHubRedeployerInitialized
    {
        console2.log(
            "Unregistering %d tokens from the old PantosHub",
            _ownedTokens.length
        );
        for (uint256 i = 0; i < _ownedTokens.length; i++) {
            PantosTypes.TokenRecord memory tokenRecord = _oldPantosHub
                .getTokenRecord(address(_ownedTokens[i]));
            if (tokenRecord.active) {
                _oldPantosHub.unregisterToken(address(_ownedTokens[i]));
                console2.log(
                    "Unregistered token %s from the old PantosHub",
                    address(_ownedTokens[i])
                );
            } else {
                console2.log(
                    "Already unregistered token %s from the old PantosHub",
                    address(_ownedTokens[i])
                );
            }
        }
    }
}
