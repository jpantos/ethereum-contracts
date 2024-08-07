// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {IPantosHub} from "../src/interfaces/IPantosHub.sol";
import {PantosForwarder} from "../src/PantosForwarder.sol";
import {PantosToken} from "../src/PantosToken.sol";
import {BitpandaEcosystemToken} from "../src/BitpandaEcosystemToken.sol";

import {PantosHubDeployer, DeployedFacets} from "./helpers/PantosHubDeployer.s.sol";
import {PantosForwarderDeployer} from "./helpers/PantosForwarderDeployer.s.sol";
import {PantosWrapperDeployer} from "./helpers/PantosWrapperDeployer.s.sol";
import {PantosTokenDeployer} from "./helpers/PantosTokenDeployer.s.sol";
import {BitpandaEcosystemTokenDeployer} from "./helpers/BitpandaEcosystemTokenDeployer.s.sol";

/**
 * @title DeployContracts
 *
 * @notice Deploy and initialize all the Pantos smart contracts on an
 * Ethereum-compatible single blockchain.
 *
 * @dev Usage
 * forge script ./script/DeployContracts.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "run(address,uint256,uint256,uint256,address[])" <validator> <panSupply> \
 *     <bestSupply> <nextTransferId> <otherValidators>
 */
contract DeployContracts is
    PantosHubDeployer,
    PantosForwarderDeployer,
    PantosWrapperDeployer,
    PantosTokenDeployer,
    BitpandaEcosystemTokenDeployer
{
    IPantosHub public pantosHubProxy;
    PantosForwarder public pantosForwarder;
    PantosToken public pantosToken;
    BitpandaEcosystemToken public bitpandaEcosystemToken;

    function exportContractAddresses() public {
        string memory blockchainName = determineBlockchain().name;
        string memory addresses;
        for (uint256 i; i < pantosWrappers.length; i++) {
            vm.serializeAddress(
                addresses,
                pantosWrappers[i].symbol(),
                address(pantosWrappers[i])
            );
        }

        vm.serializeAddress(addresses, "hub_proxy", address(pantosHubProxy));
        vm.serializeAddress(addresses, "forwarder", address(pantosForwarder));
        vm.serializeAddress(addresses, "pan", address(pantosToken));
        addresses = vm.serializeAddress(
            addresses,
            "best",
            address(bitpandaEcosystemToken)
        );
        vm.writeJson(addresses, string.concat(blockchainName, ".json"));
    }

    function run(
        address primaryValidator,
        uint256 panSupply,
        uint256 bestSupply,
        uint256 nextTransferId,
        address[] memory otherValidators
    ) public {
        vm.startBroadcast();

        (pantosHubProxy, ) = deployPantosHub(nextTransferId);

        pantosForwarder = deployPantosForwarder();
        pantosToken = deployPantosToken(panSupply);
        bitpandaEcosystemToken = deployBitpandaEcosystemToken(bestSupply);

        deployCoinWrappers();

        initializePantosHub(
            pantosHubProxy,
            pantosForwarder,
            pantosToken,
            primaryValidator
        );

        // all validator node addresses
        address[] memory validatorNodeAddresses = new address[](
            otherValidators.length + 1
        );
        validatorNodeAddresses[0] = primaryValidator;
        for (uint i; i < otherValidators.length; i++) {
            validatorNodeAddresses[i + 1] = otherValidators[i];
        }

        initializePantosForwarder(
            pantosForwarder,
            pantosHubProxy,
            pantosToken,
            validatorNodeAddresses
        );

        initializePantosToken(pantosToken, pantosForwarder);
        initializeBitpandaEcosystemToken(
            bitpandaEcosystemToken,
            pantosHubProxy,
            pantosForwarder
        );
        initializePantosWrappers(pantosHubProxy, pantosForwarder);

        vm.stopBroadcast();

        exportContractAddresses();
    }
}
