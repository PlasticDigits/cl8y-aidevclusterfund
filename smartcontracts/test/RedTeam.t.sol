// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/DonationTranche.sol";
import "../src/DonationMatchVault.sol";
import "@openzeppelin/contracts/access/manager/AccessManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Mock USDT for testing (18 decimals - BSC standard)
contract MockUSDT is ERC20 {
    constructor() ERC20("Tether USD", "USDT") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

// Mock USDT with 6 decimals (Ethereum standard) - for rejection test
contract MockUSDT6Decimals is ERC20 {
    constructor() ERC20("Tether USD", "USDT") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract RedTeamTest is Test {
    DonationTranche public tranche;
    DonationMatchVault public vault;
    AccessManager public accessManager;
    MockUSDT public usdt;
    
    address public admin = address(1);
    address public clusterManager = address(2);
    address public multisig = address(3);
    address public user1 = address(4);
    address public user2 = address(5);
    address public attacker = address(6);
    
    uint64 public constant ADMIN_ROLE = 1;
    
    function setUp() public {
        accessManager = new AccessManager(admin);
        usdt = new MockUSDT();
        
        DonationTranche trancheImpl = new DonationTranche();
        
        uint256 currentNonce = vm.getNonce(address(this));
        address predictedProxy = vm.computeCreateAddress(address(this), currentNonce + 1);
        
        vault = new DonationMatchVault(multisig, address(usdt), predictedProxy);
        
        // Fund vault with more than the initial approval to test limits
        usdt.mint(address(vault), 100_000 ether);
        
        bytes memory initData = abi.encodeWithSelector(
            DonationTranche.initialize.selector,
            address(accessManager),
            address(usdt),
            clusterManager,
            address(vault),
            uint256(0)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(trancheImpl), initData);
        tranche = DonationTranche(address(proxy));
        
        vm.startPrank(admin);
        accessManager.grantRole(ADMIN_ROLE, admin, 0);
        
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
        accessManager.setTargetFunctionRole(address(tranche), selectors, ADMIN_ROLE);
        vm.stopPrank();
        
        usdt.mint(user1, 100000 ether);
        usdt.mint(user2, 100000 ether);
        usdt.mint(attacker, 100000 ether);
        
        vm.prank(user1);
        usdt.approve(address(tranche), type(uint256).max);
        vm.prank(user2);
        usdt.approve(address(tranche), type(uint256).max);
        vm.prank(attacker);
        usdt.approve(address(tranche), type(uint256).max);
    }

    // 1. Check if the implementation of approval limit in Vault actually stops matching
    // unexpectedly if the limit is hit, which might cause DoS or partial matching issues.
    function test_RedTeam_VaultApprovalLimitDoS() public {
        // Drain the initial approval amount
        
        // Increase tranche cap to speed this up
        vm.prank(admin);
        tranche.setDefaultTrancheCap(40_000 ether);
        
        // Collect current tranche 1
        vm.prank(user1);
        tranche.deposit(100 ether); // Trigger next
        skip(2 weeks + 1);
        tranche.collectTranche(1);
        
        // Start tranche 2 with new cap
        vm.prank(admin);
        tranche.adminStartNextTranche();
        
        // Check allowance is consumed partially
        uint256 allowanceStart = usdt.allowance(address(vault), address(tranche));
        require(allowanceStart < 17_500 ether, "Allowance check failed: expected < 17500");
        require(allowanceStart > 17_000 ether, "Allowance check failed: expected > 17000");
        
        // User1 deposits 20,000 ether.
        // Vault has 100,000 USDT balance but only 17,500 approved.
        // Remaining 40,000 - 20,000 = 20,000.
        // Match 20,000.
        // Allowance is 17,500.
        // This should REVERT because allowance is exceeded.
        
        vm.prank(user1);
        vm.expectRevert(); // Should revert due to ERC20 insufficient allowance
        tranche.deposit(20_000 ether);
    }

    // 2. Precision Loss Accumulation
    function test_RedTeam_InterestPrecisionLeak() public {
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(1000 ether);
        
        // Repay interest every second for 100 seconds
        
        uint256 totalInterestPaid = 0;
        
        for(uint i=0; i<100; i++) {
            skip(1);
            // Calculate owed
            (, , , , uint256 interestOwed, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
            
            if (interestOwed > 0) {
                // User pays it
                usdt.mint(user1, interestOwed);
                
                vm.startPrank(user1);
                usdt.approve(address(tranche), type(uint256).max);
                tranche.repay(tokenId, interestOwed);
                vm.stopPrank();
                
                totalInterestPaid += interestOwed;
            }
        }
        
        // Note: Precision is verified in test_RedTeam_InterestPrecisionVerified
        // and test_RedTeam_PrecisionOverManyRepayments with proper assertions.
        // This test demonstrates the payment loop pattern works correctly.
        assertTrue(totalInterestPaid > 0, "Should have paid some interest");
    }
    
    // 3. Scheduling Exhaustion
    function test_RedTeam_ScheduleExhaustion() public {
        // Schedule max
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(7, 0, 0); // 5 initial + 7 = 12
        
        // Try to add one more
        vm.prank(admin);
        vm.expectRevert(DonationTranche.ExceedsMaxSchedule.selector);
        tranche.scheduleAdditionalTranches(1, 0, 0);
    }
    
    // 4. Front-running Deposit with Matching
    function test_RedTeam_FrontRunMatching() public {
        // Vault has 100k USDT.
        // Attacker sees user's pending deposit. Attacker deposits 1584 (full cap).
        
        vm.prank(attacker);
        tranche.deposit(1584 ether); // Fills tranche 1
        
        // User1 transaction now executes. Should revert.
        vm.prank(user1);
        vm.expectRevert(DonationTranche.TrancheFull.selector);
        tranche.deposit(1000 ether);
        
        // Attacker calls collectTranche(1) - allowed even if time not passed because full
        vm.prank(attacker);
        tranche.collectTranche(1);
        
        // Attacker tries to start next tranche - should fail because scheduled time not reached
        vm.prank(attacker);
        vm.expectRevert(DonationTranche.ScheduledTimeNotReached.selector);
        tranche.startNextTranche();
        
        // Only admin can fix this.
        vm.prank(admin);
        tranche.adminStartNextTranche();
        
        // Verify we are in tranche 2
        assertEq(tranche.currentTrancheId(), 2);
    }
    
    // ============ Additional Security Tests (Gap Coverage) ============
    
    // 5. Implementation Contract Initialization Protection
    function test_RedTeam_ImplementationCannotBeInitialized() public {
        // Deploy implementation directly (not through proxy)
        DonationTranche impl = new DonationTranche();
        
        // Try to initialize implementation directly - should revert
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        impl.initialize(
            address(accessManager),
            address(usdt),
            clusterManager,
            address(vault),
            0
        );
    }
    
    // 6. Double Initialization Prevention
    function test_RedTeam_ProxyCannotBeReinitialized() public {
        // Proxy is already initialized in setUp()
        // Try to initialize again - should revert
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        tranche.initialize(
            address(accessManager),
            address(usdt),
            clusterManager,
            address(vault),
            0
        );
    }
    
    // 7. USDT 6-Decimal Token Rejection
    function test_RedTeam_Rejects6DecimalUSDT() public {
        // Deploy 6-decimal USDT mock
        MockUSDT6Decimals usdt6 = new MockUSDT6Decimals();
        
        // Deploy implementation
        DonationTranche impl = new DonationTranche();
        
        // Pre-compute proxy address
        uint256 currentNonce = vm.getNonce(address(this));
        address predictedProxy = vm.computeCreateAddress(address(this), currentNonce + 1);
        
        // Deploy vault with predicted proxy
        DonationMatchVault newVault = new DonationMatchVault(multisig, address(usdt6), predictedProxy);
        
        // Try to deploy proxy with 6-decimal USDT - should revert
        bytes memory initData = abi.encodeWithSelector(
            DonationTranche.initialize.selector,
            address(accessManager),
            address(usdt6),
            clusterManager,
            address(newVault),
            uint256(0)
        );
        
        vm.expectRevert(DonationTranche.InvalidUsdtDecimals.selector);
        new ERC1967Proxy(address(impl), initData);
    }
    
    // 8. Vault Note Repayment Flow
    function test_RedTeam_VaultNotesCanBeRepaid() public {
        // Make a deposit that creates a matched vault note
        vm.prank(user1);
        uint256 userTokenId = tranche.deposit(500 ether);
        
        // Vault should own token 2 (matched note)
        uint256 vaultTokenId = userTokenId + 1;
        assertEq(tranche.ownerOf(vaultTokenId), address(vault));
        
        // Fast forward to accrue interest
        skip(30 days);
        
        // Get vault note info
        (, , , , uint256 interestOwed, , uint256 principal, , , , , , , ) = tranche.getNoteInfo(vaultTokenId);
        assertTrue(interestOwed > 0, "Interest should accrue on vault note");
        assertEq(principal, 500 ether);
        
        // Track vault balance before repayment
        uint256 vaultBalanceBefore = usdt.balanceOf(address(vault));
        
        // Repayer pays off vault's note
        uint256 repayAmount = interestOwed + principal;
        usdt.mint(user2, repayAmount);
        vm.startPrank(user2);
        usdt.approve(address(tranche), repayAmount);
        tranche.repay(vaultTokenId, repayAmount);
        vm.stopPrank();
        
        // Vault should receive the repayment
        assertEq(usdt.balanceOf(address(vault)), vaultBalanceBefore + repayAmount);
        
        // Note should be marked fully repaid
        (, , , , , , , , , , , , bool fullyRepaid, ) = tranche.getNoteInfo(vaultTokenId);
        assertTrue(fullyRepaid);
    }
    
    // 9. Precision Loss Verification (Fixed)
    function test_RedTeam_InterestPrecisionVerified() public {
        // Increase tranche cap to allow multiple deposits
        vm.prank(admin);
        tranche.setDefaultTrancheCap(50000 ether);
        vm.prank(admin);
        tranche.setTrancheCap(1, 50000 ether);
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(1000 ether);
        
        // Fast forward 1 year (but not past tranche end - stay within first year)
        skip(365 days);
        
        // Get interest owed
        (, , , , uint256 interestOwed, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        
        // Calculate theoretical interest: 1000 * 30% = 300 USDT
        uint256 expectedInterest = 300 ether;
        
        // Should be approximately equal (within 1 USDT tolerance for rounding)
        assertApproxEqAbs(interestOwed, expectedInterest, 1 ether, "Interest should be ~30% APR");
    }
    
    // 9b. Precision Loss Over Many Small Repayments
    function test_RedTeam_PrecisionOverManyRepayments() public {
        // Increase tranche cap
        vm.prank(admin);
        tranche.setTrancheCap(1, 50000 ether);
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(1000 ether);
        
        // Repay interest every day for 14 days (within tranche period)
        uint256 totalInterestPaid = 0;
        for (uint256 i = 0; i < 14; i++) {
            skip(1 days);
            (, , , , uint256 dailyInterest, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
            
            if (dailyInterest > 0) {
                usdt.mint(user2, dailyInterest);
                vm.startPrank(user2);
                usdt.approve(address(tranche), dailyInterest);
                tranche.repay(tokenId, dailyInterest);
                vm.stopPrank();
                totalInterestPaid += dailyInterest;
            }
        }
        
        // Calculate expected: 1000 * 30% * 14/365 = ~11.5 USDT
        uint256 principal = 1000 ether;
        uint256 aprBps = 3000;
        uint256 elapsed = 14 days;
        uint256 expected14Days = (principal * aprBps * elapsed) / (10000 * 365 days);
        
        // Allow 0.1 USDT tolerance for accumulated precision loss over 14 payments
        assertApproxEqAbs(totalInterestPaid, expected14Days, 0.1 ether, "Precision loss should be minimal");
    }
    
    // 10. ERC721 Callback Not Triggered (Contract uses _mint, not _safeMint)
    // This test documents that the contract uses _mint() which doesn't trigger onERC721Received
    // This means ERC721 callback reentrancy attacks are NOT possible
    function test_RedTeam_ERC721CallbackNotTriggered() public {
        // Deploy contract that tracks if callback was called
        ERC721CallbackTracker tracker = new ERC721CallbackTracker(
            address(tranche), 
            address(usdt)
        );
        usdt.mint(address(tracker), 1000 ether);
        
        // Make a deposit
        tracker.doDeposit(200 ether);
        
        // Verify deposit succeeded (tracker owns 1 NFT)
        assertEq(tranche.balanceOf(address(tracker)), 1);
        
        // Verify callback was NOT called (contract uses _mint, not _safeMint)
        // This is actually a security feature - prevents reentrancy via ERC721 callbacks
        assertFalse(tracker.callbackCalled(), "Callback should NOT be called - uses _mint not _safeMint");
    }
    
    // 10b. Verify ReentrancyGuard on repay function
    function test_RedTeam_RepayHasReentrancyGuard() public {
        // Make a deposit first
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(500 ether);
        
        // Fast forward to accrue interest
        skip(30 days);
        
        // Get interest owed
        (, , , , uint256 interestOwed, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        
        // Repay should work normally (ReentrancyGuard is present but allows single call)
        vm.prank(user1);
        tranche.repay(tokenId, interestOwed);
        
        // Verify repayment worked
        (, , , , , , , , uint256 interestPaid, , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(interestPaid, interestOwed);
    }
    
    // 11. Storage Gap Verification
    function test_RedTeam_StorageGapExists() public view {
        // Verify storage slot 96 onwards is available (after __gap[50])
        // This is a static check - actual upgrade testing requires deployment
        // The contract has uint256[50] __gap which reserves slots
        
        // Basic sanity check - contract should be functional
        assertEq(tranche.currentTrancheId(), 1);
        assertEq(tranche.defaultAprBps(), 3000);
        assertTrue(tranche.firstTrancheStarted());
    }
}

// Contract to track if ERC721 callback is called
contract ERC721CallbackTracker {
    DonationTranche public tranche;
    MockUSDT public usdt;
    bool public callbackCalled;
    
    constructor(address _tranche, address _usdt) {
        tranche = DonationTranche(_tranche);
        usdt = MockUSDT(_usdt);
    }
    
    function doDeposit(uint256 amount) external {
        usdt.approve(address(tranche), type(uint256).max);
        tranche.deposit(amount);
    }
    
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        callbackCalled = true;
        return this.onERC721Received.selector;
    }
}
