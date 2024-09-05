// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {PantosToken} from "../../src/PantosToken.sol";

import {PantosHubDeployer} from "../helpers/PantosHubDeployerNew.s.sol";
import {PantosRegistryFacet} from "../../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../../src/facets/PantosTransferFacet.sol";

/**
 * @title UpgradeHub
 *
 * @notice Deploy and upgrade facets of the Pantos Hub.
 *
 * @dev Usage
 * forge script ./script/redeploy/UpgradeHub.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "run(address)" <pantosHubProxyAddress>
 */
contract UpgradeHub is PantosHubDeployer {
    PantosRegistryFacet registryFacet;
    PantosTransferFacet transferFacet;

    function exportContractAddresses() public {
        string memory blockchainName = determineBlockchain().name;
        string memory addresses;
        // for (uint256 i; i < pantosWrappers.length; i++) {
        //     vm.serializeAddress(
        //         "addresses",
        //         pantosWrappers[i].symbol(),
        //         address(pantosWrappers[i])
        //     );
        // }

        // vm.serializeAddress("addresses", "hub_proxy", address(pantosHubProxy));
        // vm.serializeAddress("addresses", "hub_init", address(pantosHubInit));
        // vm.serializeAddress(
        //     "addresses",
        //     "diamond_cut_facet",
        //     address(pantosFacets.dCut)
        // );
        // vm.serializeAddress(
        //     "addresses",
        //     "diamond_loupe_facet",
        //     address(pantosFacets.dLoupe)
        // );
        vm.serializeAddress(
            "addresses",
            "registry_facet",
            address(registryFacet)
        );
        addresses = vm.serializeAddress(
            "addresses",
            "transfer_facet",
            address(transferFacet)
        );

        // vm.serializeAddress(
        //     "addresses",
        //     "forwarder",
        //     address(pantosForwarder)
        // );
        // vm.serializeAddress("addresses", "pan", address(pantosToken));
        // vm.serializeAddress(
        //     "addresses",
        //     "access_controller",
        //     address(accessController)
        // );
        // addresses = vm.serializeAddress(
        //     "addresses",
        //     "best",
        //     address(bitpandaEcosystemToken)
        // );
        vm.writeJson(addresses, string.concat(blockchainName, ".json"));
    }

    function importContractAddresses() public {
        Blockchain memory blockchain = determineBlockchain();
        readContractAddresses(blockchain);
        registryFacet = PantosRegistryFacet(
            getContractAddress(blockchain, "registry_facet")
        );
        transferFacet = PantosTransferFacet(
            getContractAddress(blockchain, "transfer_facet")
        );
    }

    function deploy() public {
        vm.startBroadcast();
        registryFacet = deployRegistryFacet();
        transferFacet = deployTransferFacet();
        vm.stopBroadcast();
        exportContractAddresses();
    }

    function roleActions() public {
        address pantosHubProxyAddress; // FIXME: need this from Base Address helper
        AccessController accessController; // FIXME: need this from Base Address helper

        importContractAddresses();
        IPantosHub pantosHub = IPantosHub(pantosHubProxyAddress);

        // Ensuring PantosHub is paused at the time of diamond cut
        if (!pantosHub.paused()) {
            vm.broadcast(accessController.pauser());
            pantosHub.pause();
            console.log("PantosHub: paused=%s", pantosHub.paused());
        }

        vm.broadcast(accessController.deployer());
        diamondCutUpgradeFacets(
            pantosHubProxyAddress,
            registryFacet,
            transferFacet
        );

        vm.broadcast(accessController.deployer());
        // this will do nothing if there is nothing new added to the storage slots
        // FIXME: can we use the json valuse to pass in to this method ?
        initializePantosHub(
            pantosHub,
            PantosForwarder(pantosHub.getPantosForwarder()),
            PantosToken(pantosHub.getPantosToken()),
            pantosHub.getPrimaryValidatorNode()
        );
    }
}
