// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/mocks/MockUSDT.sol";
import "../src/DonationTranche.sol";
import "../src/DonationMatchVault.sol";
import "@openzeppelin/contracts/access/manager/AccessManager.sol";

/**
 * @title DeployLocal
 * @notice Deploys full stack to Anvil for local testing
 * @dev Uses Anvil's default accounts - NEVER use on mainnet
 */
contract DeployLocalScript is Script {
    // Anvil default accounts
    address constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant USER1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant USER2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    // Role IDs for AccessManager
    uint64 constant ADMIN_ROLE = 0; // Default admin role in OpenZeppelin AccessManager

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy AccessManager with deployer as initial admin
        AccessManager accessManager = new AccessManager(DEPLOYER);
        console.log("AccessManager deployed at:", address(accessManager));

        // 2. Deploy MockUSDT
        MockUSDT usdt = new MockUSDT();
        console.log("MockUSDT deployed at:", address(usdt));

        // 3. Mint USDT to test accounts (100,000 each)
        usdt.mint(DEPLOYER, 100_000 ether);
        usdt.mint(USER1, 100_000 ether);
        usdt.mint(USER2, 100_000 ether);
        console.log("Minted 100,000 USDT to deployer, user1, user2");

        // 4. Deploy DonationMatchVault (deployer is owner)
        DonationMatchVault vault = new DonationMatchVault(
            DEPLOYER,
            address(usdt)
        );
        console.log("Vault deployed at:", address(vault));

        // 5. Deploy DonationTranche with AccessManager as authority
        DonationTranche tranche = new DonationTranche(
            address(accessManager),
            address(usdt),
            DEPLOYER,  // clusterManager - receives collected funds
            address(vault)
        );
        console.log("Tranche deployed at:", address(tranche));

        // 6. Grant deployer permission to call restricted functions on tranche
        // setTargetFunctionRole allows ADMIN_ROLE to call all functions on tranche
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = DonationTranche.startFirstTranche.selector;
        selectors[1] = DonationTranche.startNextTranche.selector;
        selectors[2] = DonationTranche.scheduleAdditionalTranches.selector;
        selectors[3] = DonationTranche.setVault.selector;
        selectors[4] = DonationTranche.setDefaultApr.selector;
        accessManager.setTargetFunctionRole(address(tranche), selectors, ADMIN_ROLE);
        accessManager.grantRole(ADMIN_ROLE, DEPLOYER, 0);
        console.log("Granted admin access to tranche functions");

        // 7. Fund vault with USDT for matching (50,000 USDT)
        usdt.transfer(address(vault), 50_000 ether);
        console.log("Transferred 50,000 USDT to vault");

        // 8. Approve tranche to spend vault's USDT (unlimited)
        vault.approveUsdt(address(tranche), type(uint256).max);
        console.log("Vault approved tranche for unlimited USDT");

        // 9. Start first tranche.
        tranche.startFirstTranche(0);

        vm.stopBroadcast();

        // Print summary
        console.log("\n=== Deployment Summary ===");
        console.log("AccessManager:", address(accessManager));
        console.log("MockUSDT:", address(usdt));
        console.log("Vault:", address(vault));
        console.log("Tranche:", address(tranche));
        console.log("\n=== Test Accounts ===");
        console.log("Deployer:", DEPLOYER, "- 100,000 USDT (admin)");
        console.log("User1:", USER1, "- 100,000 USDT");
        console.log("User2:", USER2, "- 100,000 USDT");
        console.log("\n=== Ready for Testing ===");
    }
}
