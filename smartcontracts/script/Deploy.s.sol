// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/DonationTranche.sol";
import "../src/DonationMatchVault.sol";

contract DeployScript is Script {
    // BSC Addresses
    address constant ACCESS_MANAGER = 0x5823a01A5372B779cB091e47DBBb176F2831b4c7;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant CLUSTER_MANAGER = 0x30789c78b7640947db349e319991aaeC416eeB93;
    address constant VAULT_OWNER = 0x745A676C5c472b50B50e18D4b59e9AeEEc597046;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Vault first
        DonationMatchVault vault = new DonationMatchVault(
            VAULT_OWNER,
            USDT
        );
        console.log("DonationMatchVault deployed at:", address(vault));

        // Deploy DonationTranche
        DonationTranche tranche = new DonationTranche(
            ACCESS_MANAGER,
            USDT,
            CLUSTER_MANAGER,
            address(vault)
        );
        console.log("DonationTranche deployed at:", address(tranche));

        vm.stopBroadcast();

        // Post-deployment instructions
        console.log("\n=== Post-Deployment Steps ===");
        console.log("1. Fund the vault with USDT for matching");
        console.log("");
        console.log("2. IMPORTANT: Vault must approve tranche BEFORE any deposits can be matched!");
        console.log("   Vault owner calls:");
        console.log("   vault.approveUsdt(");
        console.log("     ", address(tranche), ",");
        console.log("     type(uint256).max");
        console.log("   )");
        console.log("");
        console.log("3. Admin must call tranche.startFirstTranche() via AccessManager");
        console.log("");
        console.log("4. Update frontend .env:");
        console.log("   VITE_DONATION_TRANCHE_ADDRESS=", address(tranche));
        console.log("   VITE_DONATION_VAULT_ADDRESS=", address(vault));
    }
}
