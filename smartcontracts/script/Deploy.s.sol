// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/DonationTranche.sol";
import "../src/DonationMatchVault.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    // BSC Addresses
    address constant ACCESS_MANAGER = 0x5823a01A5372B779cB091e47DBBb176F2831b4c7;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant CLUSTER_MANAGER = 0x30789c78b7640947db349e319991aaeC416eeB93;
    address constant VAULT_OWNER = 0x745A676C5c472b50B50e18D4b59e9AeEEc597046;
    
    // First tranche start time (0 = start immediately at deployment)
    // 1769945400 = Sunday, February 1, 2026 11:30:00 AM GMT
    uint256 constant FIRST_TRANCHE_START = 1769945400;

    function run() external {
        // Get deployer address from --sender flag (interactive wallet flow)
        address deployer = msg.sender;
        
        vm.startBroadcast();

        // 1. Deploy DonationTranche implementation first
        DonationTranche trancheImplementation = new DonationTranche();
        console.log("DonationTranche implementation deployed at:", address(trancheImplementation));

        // 2. Pre-compute proxy address using CREATE2 or deployer nonce
        // For CREATE: proxy will be deployed at nonce+2 from current position
        // We need to compute this address before deploying the vault
        uint256 currentNonce = vm.getNonce(deployer);
        address predictedProxy = vm.computeCreateAddress(deployer, currentNonce + 1);
        console.log("Predicted proxy address:", predictedProxy);

        // 3. Deploy Vault with pre-approved proxy address
        DonationMatchVault vault = new DonationMatchVault(
            VAULT_OWNER,
            USDT,
            predictedProxy
        );
        console.log("DonationMatchVault deployed at:", address(vault));
        console.log("Vault pre-approved proxy for unlimited USDT");

        // 4. Encode initialization data (includes first tranche start)
        bytes memory initData = abi.encodeWithSelector(
            DonationTranche.initialize.selector,
            ACCESS_MANAGER,
            USDT,
            CLUSTER_MANAGER,
            address(vault),
            FIRST_TRANCHE_START
        );

        // 5. Deploy ERC1967 proxy pointing to implementation
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(trancheImplementation),
            initData
        );
        console.log("DonationTranche proxy deployed at:", address(proxy));
        
        // Verify predicted address matches actual
        require(address(proxy) == predictedProxy, "Proxy address mismatch!");

        // Cast proxy to DonationTranche interface for verification
        DonationTranche tranche = DonationTranche(address(proxy));
        console.log("Tranche initialized - nextTokenId:", tranche.nextTokenId());
        console.log("First tranche started:", tranche.firstTrancheStarted());
        console.log("Current tranche ID:", tranche.currentTrancheId());

        vm.stopBroadcast();

        // Post-deployment instructions
        console.log("\n=== Post-Deployment Steps ===");
        console.log("1. Fund the vault with USDT for matching");
        console.log("");
        console.log("2. Update frontend .env:");
        console.log("   VITE_DONATION_TRANCHE_ADDRESS=", address(proxy));
        console.log("   VITE_DONATION_VAULT_ADDRESS=", address(vault));
        console.log("");
        console.log("=== Upgrade Information ===");
        console.log("Implementation:", address(trancheImplementation));
        console.log("Proxy:", address(proxy));
        console.log("To upgrade, deploy new implementation and call proxy.upgradeToAndCall()");
    }
}
