// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/mocks/MockUSDT.sol";
import "../src/DonationTranche.sol";
import "../src/DonationMatchVault.sol";
import "@openzeppelin/contracts/access/manager/AccessManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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

        // 4. Deploy DonationTranche implementation first
        DonationTranche trancheImplementation = new DonationTranche();
        console.log("Tranche implementation deployed at:", address(trancheImplementation));

        // 5. Pre-compute proxy address
        uint256 currentNonce = vm.getNonce(DEPLOYER);
        address predictedProxy = vm.computeCreateAddress(DEPLOYER, currentNonce + 1);
        console.log("Predicted proxy address:", predictedProxy);

        // 6. Deploy DonationMatchVault with pre-approved proxy address
        DonationMatchVault vault = new DonationMatchVault(
            DEPLOYER,
            address(usdt),
            predictedProxy
        );
        console.log("Vault deployed at:", address(vault));

        // 7. Encode initialization data (first tranche starts immediately)
        bytes memory initData = abi.encodeWithSelector(
            DonationTranche.initialize.selector,
            address(accessManager),
            address(usdt),
            DEPLOYER,  // clusterManager - receives collected funds
            address(vault),
            uint256(0)  // firstTrancheStart = 0 means start immediately
        );

        // 8. Deploy ERC1967 proxy pointing to implementation
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(trancheImplementation),
            initData
        );
        console.log("Tranche proxy deployed at:", address(proxy));
        require(address(proxy) == predictedProxy, "Proxy address mismatch!");

        // Cast proxy to DonationTranche for subsequent calls
        DonationTranche tranche = DonationTranche(address(proxy));

        // 9. Grant deployer permission to call restricted functions on tranche proxy
        bytes4[] memory selectors = new bytes4[](11);
        selectors[0] = DonationTranche.adminStartNextTranche.selector;
        selectors[1] = DonationTranche.scheduleAdditionalTranches.selector;
        selectors[2] = DonationTranche.setVault.selector;
        selectors[3] = DonationTranche.setDefaultApr.selector;
        selectors[4] = DonationTranche.setDefaultTrancheCap.selector;
        selectors[5] = DonationTranche.setTrancheCap.selector;
        selectors[6] = DonationTranche.setClusterManager.selector;
        selectors[7] = DonationTranche.adminRescueTokens.selector;
        selectors[8] = bytes4(keccak256("upgradeToAndCall(address,bytes)"));
        selectors[9] = DonationTranche.pause.selector;
        selectors[10] = DonationTranche.unpause.selector;
        accessManager.setTargetFunctionRole(address(proxy), selectors, ADMIN_ROLE);
        accessManager.grantRole(ADMIN_ROLE, DEPLOYER, 0);
        console.log("Granted admin access to tranche functions");

        // 10. Fund vault with USDT for matching (50,000 USDT)
        usdt.mint(address(vault), 50_000 ether);
        console.log("Minted 50,000 USDT to vault for matching");

        vm.stopBroadcast();

        // Print summary
        console.log("\n=== Deployment Summary ===");
        console.log("AccessManager:", address(accessManager));
        console.log("MockUSDT:", address(usdt));
        console.log("Vault:", address(vault));
        console.log("Tranche (proxy):", address(proxy));
        console.log("Tranche (impl):", address(trancheImplementation));
        console.log("First tranche started:", tranche.firstTrancheStarted());
        console.log("Current tranche ID:", tranche.currentTrancheId());
        console.log("\n=== Test Accounts ===");
        console.log("Deployer:", DEPLOYER, "- 100,000 USDT (admin)");
        console.log("User1:", USER1, "- 100,000 USDT");
        console.log("User2:", USER2, "- 100,000 USDT");
        console.log("\n=== Ready for Testing ===");
    }
}
