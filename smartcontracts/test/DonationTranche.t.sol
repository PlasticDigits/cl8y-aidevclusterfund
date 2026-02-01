// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/DonationTranche.sol";
import "../src/DonationMatchVault.sol";
import "@openzeppelin/contracts/access/manager/AccessManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Mock USDT for testing
contract MockUSDT is ERC20 {
    constructor() ERC20("Tether USD", "USDT") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

contract DonationTrancheTest is Test {
    DonationTranche public tranche;
    DonationMatchVault public vault;
    AccessManager public accessManager;
    MockUSDT public usdt;
    
    address public admin = address(1);
    address public clusterManager = address(2);
    address public multisig = address(3);
    address public user1 = address(4);
    address public user2 = address(5);
    address public repayer = address(6);
    
    uint64 public constant ADMIN_ROLE = 1;
    
    function setUp() public {
        // Deploy AccessManager
        accessManager = new AccessManager(admin);
        
        // Deploy mock USDT
        usdt = new MockUSDT();
        
        // Deploy DonationTranche implementation first
        DonationTranche trancheImpl = new DonationTranche();
        
        // Pre-compute proxy address for vault to approve
        uint256 currentNonce = vm.getNonce(address(this));
        address predictedProxy = vm.computeCreateAddress(address(this), currentNonce + 1);
        
        // Deploy vault with pre-approved proxy address
        vault = new DonationMatchVault(multisig, address(usdt), predictedProxy);
        
        // Deploy proxy with initialization (first tranche starts immediately)
        bytes memory initData = abi.encodeWithSelector(
            DonationTranche.initialize.selector,
            address(accessManager),
            address(usdt),
            clusterManager,
            address(vault),
            uint256(0) // Start first tranche immediately
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(trancheImpl), initData);
        tranche = DonationTranche(address(proxy));
        
        require(address(proxy) == predictedProxy, "Proxy address mismatch");
        
        // Setup access control - grant admin role to admin address
        vm.startPrank(admin);
        accessManager.grantRole(ADMIN_ROLE, admin, 0);
        
        // Set target function roles for DonationTranche
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
        
        // Mint USDT to users and vault
        usdt.mint(user1, 10000 ether);
        usdt.mint(user2, 10000 ether);
        usdt.mint(repayer, 10000 ether);
        usdt.mint(address(vault), 5000 ether);
        
        // Approve tranche contract
        vm.prank(user1);
        usdt.approve(address(tranche), type(uint256).max);
        
        vm.prank(user2);
        usdt.approve(address(tranche), type(uint256).max);
        
        vm.prank(repayer);
        usdt.approve(address(tranche), type(uint256).max);
    }
    
    // ============ Initialization Tests ============
    
    function test_InitialState() public view {
        assertEq(address(tranche.usdt()), address(usdt));
        assertEq(tranche.clusterManager(), clusterManager);
        assertEq(tranche.vault(), address(vault));
        assertEq(tranche.defaultAprBps(), 3000);
        // First tranche is now started during initialization
        assertTrue(tranche.firstTrancheStarted());
        assertEq(tranche.currentTrancheId(), 1);
        // 5 remaining scheduled tranches (6 - 1 started)
        assertEq(tranche.scheduledTrancheCount(), 5);
    }
    
    function test_FirstTrancheActiveAfterInit() public view {
        assertTrue(tranche.firstTrancheStarted());
        assertEq(tranche.currentTrancheId(), 1);
        assertEq(tranche.scheduledTrancheCount(), 5);
        
        (uint256 id, uint256 startTime, uint256 endTime, uint256 cap, , , bool isActive, , ) = tranche.getCurrentTranche();
        assertEq(id, 1);
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + 2 weeks);
        assertEq(cap, 1584 ether);
        assertTrue(isActive);
    }
    
    // ============ Deposit Tests ============
    
    function test_Deposit() public {
        // First tranche already started during initialization
        
        uint256 depositAmount = 200 ether;
        uint256 userBalanceBefore = usdt.balanceOf(user1);
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(depositAmount);
        
        assertEq(tokenId, 1);
        assertEq(tranche.ownerOf(tokenId), user1);
        assertEq(usdt.balanceOf(user1), userBalanceBefore - depositAmount);
        
        // Check note info
        (
            address owner,
            uint256 trancheId,
            uint256 aprBps,
            uint256 timestamp,
            ,
            ,
            uint256 principal,
            ,
            ,
            ,
            ,
            ,
            bool fullyRepaid,
        ) = tranche.getNoteInfo(tokenId);
        
        assertEq(owner, user1);
        assertEq(trancheId, 1);
        assertEq(aprBps, 3000);
        assertEq(timestamp, block.timestamp);
        assertEq(principal, depositAmount);
        assertFalse(fullyRepaid);
    }
    
    function test_DepositWithMatching() public {
        // First tranche already started during initialization
        
        uint256 depositAmount = 200 ether;
        uint256 vaultBalanceBefore = usdt.balanceOf(address(vault));
        
        vm.prank(user1);
        uint256 userTokenId = tranche.deposit(depositAmount);
        
        // User should have token 1
        assertEq(userTokenId, 1);
        assertEq(tranche.ownerOf(1), user1);
        
        // Vault should have token 2 (matched)
        assertEq(tranche.ownerOf(2), address(vault));
        
        // Vault balance should decrease
        assertEq(usdt.balanceOf(address(vault)), vaultBalanceBefore - depositAmount);
        
        // Tranche total should be 2x deposit
        (, , , , uint256 totalDeposited, , , , ) = tranche.getCurrentTranche();
        assertEq(totalDeposited, depositAmount * 2);
    }
    
    function test_DepositWithoutMatchingWhenVaultEmpty() public {
        // Empty the vault first
        vm.prank(multisig);
        vault.withdraw();
        
        // First tranche already started during initialization
        
        uint256 depositAmount = 200 ether;
        
        vm.prank(user1);
        uint256 userTokenId = tranche.deposit(depositAmount);
        
        // User should have token 1
        assertEq(userTokenId, 1);
        
        // No token 2 should exist (no matching)
        vm.expectRevert();
        tranche.ownerOf(2);
        
        // Tranche total should be just the deposit
        (, , , , uint256 totalDeposited, , , , ) = tranche.getCurrentTranche();
        assertEq(totalDeposited, depositAmount);
    }
    
    function test_RevertDepositBelowMinimum() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        vm.expectRevert(DonationTranche.BelowMinimumDeposit.selector);
        tranche.deposit(50 ether); // Below 100 USDT minimum
    }
    
    function test_DepositExceedsCapacity_AcceptsRemaining() public {
        // First tranche already started during initialization
        
        uint256 cap = 1584 ether;
        uint256 userBalanceBefore = usdt.balanceOf(user1);
        
        // Try to deposit more than cap - should accept only the cap amount
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(2000 ether);
        
        // User should have received a note for the cap amount (half goes to user, half to matching)
        // Actually: cap/2 = 792 each for user and vault (1:1 matching)
        // No wait - user deposits up to remaining which is 1584, then matching tries to add more
        // But matching is capped to remaining after user deposit = 0
        // So user gets 1584, no matching happens
        
        // Verify user was charged the full cap (1584 ether)
        assertEq(usdt.balanceOf(user1), userBalanceBefore - cap);
        
        // Verify the note was minted with cap amount
        (, , , , , , uint256 principal, , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(principal, cap);
        
        // Verify tranche is now full
        (, , , , , uint256 remaining, bool isActive, , ) = tranche.getCurrentTranche();
        assertEq(remaining, 0);
        assertFalse(isActive); // Tranche not active when full
    }
    
    function test_RevertDepositBeforeTrancheStarts() public {
        // Deploy a new instance with future start time
        uint256 futureStart = block.timestamp + 1 days;
        
        DonationTranche trancheImpl = new DonationTranche();
        uint256 currentNonce = vm.getNonce(address(this));
        address predictedProxy = vm.computeCreateAddress(address(this), currentNonce + 1);
        
        DonationMatchVault newVault = new DonationMatchVault(multisig, address(usdt), predictedProxy);
        
        bytes memory initData = abi.encodeWithSelector(
            DonationTranche.initialize.selector,
            address(accessManager),
            address(usdt),
            clusterManager,
            address(newVault),
            futureStart
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(trancheImpl), initData);
        DonationTranche newTranche = DonationTranche(address(proxy));
        
        // Approve USDT for the new tranche
        vm.prank(user1);
        usdt.approve(address(newTranche), type(uint256).max);
        
        // Should revert because tranche hasn't started yet
        vm.prank(user1);
        vm.expectRevert(DonationTranche.TrancheNotActive.selector);
        newTranche.deposit(200 ether);
    }
    
    // ============ Repayment Tests ============
    
    function test_RepayInterestOnly() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(200 ether);
        
        // Fast forward 30 days
        skip(30 days);
        
        // Check interest owed
        (, , , , uint256 interestOwed, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertTrue(interestOwed > 0);
        
        // Repay some interest
        uint256 repayAmount = interestOwed / 2;
        uint256 user1BalanceBefore = usdt.balanceOf(user1);
        
        vm.prank(repayer);
        tranche.repay(tokenId, repayAmount);
        
        // User1 should receive the payment
        assertEq(usdt.balanceOf(user1), user1BalanceBefore + repayAmount);
        
        // Check updated note
        (, , , , , , , , uint256 interestPaid, , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(interestPaid, repayAmount);
    }
    
    function test_RepayInterestAndPrincipal() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(200 ether);
        
        // Fast forward 30 days
        skip(30 days);
        
        (, , , , uint256 interestOwed, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        
        // Repay more than interest owed
        uint256 repayAmount = interestOwed + 50 ether;
        
        vm.prank(repayer);
        tranche.repay(tokenId, repayAmount);
        
        // Check updated note
        (, , , , , , , uint256 principalRepaid, uint256 interestPaid, , uint256 remainingPrincipal, , , ) = tranche.getNoteInfo(tokenId);
        
        assertEq(interestPaid, interestOwed);
        assertEq(principalRepaid, 50 ether);
        assertEq(remainingPrincipal, 150 ether);
    }
    
    function test_FullRepaymentMarksComplete() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(100 ether); // Minimum deposit
        
        // Fast forward 30 days
        skip(30 days);
        
        (, , , , uint256 interestOwed, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        
        // Repay everything (interest + full principal)
        uint256 repayAmount = interestOwed + 100 ether;
        
        vm.prank(repayer);
        tranche.repay(tokenId, repayAmount);
        
        // Check note is marked complete
        (, , , , , , , uint256 principalRepaid, uint256 interestPaid, , , uint256 totalRepaid, bool fullyRepaid, uint256 completedTimestamp) = tranche.getNoteInfo(tokenId);
        
        assertTrue(fullyRepaid);
        assertEq(completedTimestamp, block.timestamp);
        assertEq(totalRepaid, principalRepaid + interestPaid);
        
        // NFT should still exist
        assertEq(tranche.ownerOf(tokenId), user1);
    }
    
    function test_RevertRepayFullyRepaidNote() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(100 ether);
        
        // Fully repay
        vm.prank(repayer);
        tranche.repay(tokenId, 100 ether);
        
        // Try to repay again
        vm.prank(repayer);
        vm.expectRevert(DonationTranche.NoteFullyRepaid.selector);
        tranche.repay(tokenId, 10 ether);
    }
    
    // ============ Tranche Collection Tests ============
    
    function test_CollectTranche() public {
        // First tranche already started during initialization
        
        // Make deposits
        vm.prank(user1);
        tranche.deposit(200 ether);
        
        // Fast forward past tranche end
        skip(2 weeks + 1);
        
        uint256 managerBalanceBefore = usdt.balanceOf(clusterManager);
        
        // Anyone can collect
        tranche.collectTranche(1);
        
        // Cluster manager should receive funds (200 user + 200 matched = 400)
        assertEq(usdt.balanceOf(clusterManager), managerBalanceBefore + 400 ether);
        
        // Collection doesn't auto-start next tranche (lazy progression via deposit)
        assertEq(tranche.currentTrancheId(), 1);
        assertEq(tranche.scheduledTrancheCount(), 5); // Still 5 scheduled
        
        // Next deposit triggers progression to tranche 2
        vm.prank(user1);
        tranche.deposit(100 ether);
        
        assertEq(tranche.currentTrancheId(), 2);
        assertEq(tranche.scheduledTrancheCount(), 4); // 5 - 1 = 4
    }
    
    function test_RevertCollectTrancheNotEnded() public {
        // First tranche already started during initialization
        
        vm.expectRevert(DonationTranche.TrancheNotEnded.selector);
        tranche.collectTranche(1);
    }
    
    function test_RevertCollectTrancheAlreadyCollected() public {
        // First tranche already started during initialization
        
        skip(2 weeks + 1);
        
        tranche.collectTranche(1);
        
        vm.expectRevert(DonationTranche.TrancheAlreadyCollected.selector);
        tranche.collectTranche(1);
    }
    
    function test_ExhaustAllTranchesAndRestartLater() public {
        // Start with only 2 scheduled tranches for simpler test
        // First, reduce scheduled tranches by running through them
        // First tranche already started during initialization
        
        // Run through all 6 initial tranches
        for (uint256 i = 1; i <= 6; i++) {
            // Make a deposit in each tranche
            vm.prank(user1);
            tranche.deposit(100 ether);
            
            // Fast forward past tranche end (use skip for relative time advancement)
            skip(2 weeks + 1);
            
            // Collect the tranche
            tranche.collectTranche(i);
        }
        
        // All tranches exhausted
        assertEq(tranche.scheduledTrancheCount(), 0);
        assertEq(tranche.currentTrancheId(), 6);
        
        // Verify no active tranche
        (, , , , , , bool isActive, , ) = tranche.getCurrentTranche();
        assertFalse(isActive);
        
        // Time passes... (6 months later)
        skip(180 days);
        
        // Admin schedules more tranches
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(3, 0, 0);
        assertEq(tranche.scheduledTrancheCount(), 3);
        
        // Use startNextTranche to resume after gap
        vm.prank(admin);
        tranche.startNextTranche();
        
        // Verify new tranche is active
        (uint256 id, uint256 startTime, uint256 endTime, , , , bool active, , ) = tranche.getCurrentTranche();
        assertEq(id, 7);
        assertTrue(active);
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + 2 weeks);
        assertEq(tranche.scheduledTrancheCount(), 2); // 3 - 1 = 2
        
        // Can deposit in the new tranche
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(100 ether);
        assertTrue(tokenId > 0);
    }
    
    function test_RevertStartNextTrancheWhenCurrentActive() public {
        // First tranche is active, can't start next
        vm.expectRevert(DonationTranche.TrancheStillActive.selector);
        tranche.startNextTranche();
    }
    
    function test_RevertStartNextTrancheWhenActive() public {
        // First tranche already started during initialization
        
        // Tranche is still active, can't start next
        vm.prank(admin);
        vm.expectRevert(DonationTranche.TrancheStillActive.selector);
        tranche.startNextTranche();
    }
    
    function test_RevertStartNextTrancheWhenNotCollected() public {
        // First tranche already started during initialization
        
        // Fast forward past end
        skip(2 weeks + 1);
        
        // Don't collect - tranche ended but not collected
        vm.prank(admin);
        vm.expectRevert(DonationTranche.PreviousTrancheNotCollected.selector);
        tranche.startNextTranche();
    }
    
    function test_RevertStartNextTrancheNoScheduled() public {
        // First tranche already started during initialization
        
        // Exhaust all tranches by depositing and progressing through them
        // Each deposit after time elapses triggers progression to next tranche
        for (uint256 i = 1; i <= 6; i++) {
            // Make a deposit in current tranche
            vm.prank(user1);
            tranche.deposit(100 ether);
            
            // Fast forward past tranche end
            skip(2 weeks + 1);
            
            // Collect the tranche
            tranche.collectTranche(i);
            
            // If not the last tranche, deposit to trigger next
            if (i < 6) {
                vm.prank(user1);
                tranche.deposit(100 ether);
            }
        }
        
        assertEq(tranche.scheduledTrancheCount(), 0);
        assertEq(tranche.currentTrancheId(), 6);
        
        // Try to start next without scheduling more
        vm.prank(admin);
        vm.expectRevert(DonationTranche.NoTranchesScheduled.selector);
        tranche.startNextTranche();
    }
    
    // ============ Admin Tests ============
    
    function test_ScheduleAdditionalTranches() public {
        // First tranche already started during initialization
        
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(3, 0, 0); // count=3, auto start
        
        assertEq(tranche.scheduledTrancheCount(), 8); // 5 remaining + 3 new
    }
    
    function test_SetVault() public {
        address newVault = address(100);
        
        vm.prank(admin);
        tranche.setVault(newVault);
        
        assertEq(tranche.vault(), newVault);
    }
    
    function test_SetDefaultApr() public {
        vm.prank(admin);
        tranche.setDefaultApr(5000); // 50%
        
        assertEq(tranche.defaultAprBps(), 5000);
    }
    
    // ============ Interest Calculation Tests ============
    
    function test_InterestCalculation() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(1000 ether);
        
        // Fast forward 1 year
        skip(365 days);
        
        (, , , , uint256 interestOwed, uint256 interestPerSecond, , , , , , , , ) = tranche.getNoteInfo(tokenId);
        
        // 30% of 1000 = 300 USDT per year
        // Allow for small rounding differences
        assertApproxEqAbs(interestOwed, 300 ether, 1 ether);
        
        // Interest per second = 1000 * 0.3 / 31536000 ≈ 0.0000095 ether
        assertTrue(interestPerSecond > 0);
    }
    
    // ============ ERC721Enumerable Tests ============
    
    function test_TokenEnumeration() public {
        // First tranche already started during initialization
        
        // User1 makes 3 deposits
        vm.startPrank(user1);
        uint256 tokenId1 = tranche.deposit(100 ether);
        uint256 tokenId2 = tranche.deposit(200 ether);
        uint256 tokenId3 = tranche.deposit(300 ether);
        vm.stopPrank();
        
        // Note: Each deposit also creates a matching note for vault
        // So total supply = 6 (3 user + 3 vault matched)
        assertEq(tranche.totalSupply(), 6);
        
        // User1 should have 3 tokens
        assertEq(tranche.balanceOf(user1), 3);
        
        // Verify enumeration by owner index
        assertEq(tranche.tokenOfOwnerByIndex(user1, 0), tokenId1);
        assertEq(tranche.tokenOfOwnerByIndex(user1, 1), tokenId2);
        assertEq(tranche.tokenOfOwnerByIndex(user1, 2), tokenId3);
        
        // Verify global token enumeration
        assertEq(tranche.tokenByIndex(0), tokenId1);      // user1's first deposit
        assertEq(tranche.tokenByIndex(1), tokenId1 + 1);  // vault's matching note
    }
    
    // ============ Deposit and Matching Edge Case Tests ============
    // Regression tests for tranche capacity handling
    
    /**
     * @notice Test Case 1: Tranche has zero remaining - should revert with TrancheFull
     */
    function test_DepositRevertsWhenTrancheZeroRemaining() public {
        // First tranche already started during initialization
        
        uint256 cap = 1584 ether;
        
        // Fill the tranche completely (user deposits full cap, no matching since vault will fill rest)
        vm.prank(user1);
        tranche.deposit(cap); // This fills the tranche
        
        // Now try to deposit again - should revert with TrancheFull
        vm.prank(user2);
        vm.expectRevert(DonationTranche.TrancheFull.selector);
        tranche.deposit(100 ether);
    }
    
    /**
     * @notice Test Case 2: Tranche has less remaining than amount - process with remaining
     */
    function test_DepositAcceptsRemainingWhenLessThanAmount() public {
        // First tranche already started during initialization
        
        uint256 cap = 1584 ether;
        uint256 firstDeposit = 1400 ether; // Leaves 184 remaining
        
        // First deposit fills most of tranche
        vm.prank(user1);
        tranche.deposit(firstDeposit);
        
        // First deposit + matching = 2800 ether > cap, so matching is limited
        // User deposits 1400, remaining = 184, matching gets 184
        // Total = 1400 + 184 = 1584 = cap
        
        (, , , , uint256 totalDeposited, , , , ) = tranche.getCurrentTranche();
        assertEq(totalDeposited, cap); // Tranche should be full now
    }
    
    /**
     * @notice Test Case 3: Partial deposit accepted, remaining verified
     */
    function test_DepositPartialWhenExceedsRemaining() public {
        // First tranche already started during initialization
        
        uint256 cap = 1584 ether;
        // Make small deposit first, then fill with a large one
        vm.prank(user1);
        tranche.deposit(200 ether); // 200 user + 200 match = 400
        
        (, , , , uint256 afterFirst, , , , ) = tranche.getCurrentTranche();
        assertEq(afterFirst, 400 ether);
        
        uint256 remaining = cap - afterFirst; // 1184 remaining
        uint256 user2BalanceBefore = usdt.balanceOf(user2);
        
        // User2 tries to deposit 2000, but only 1184 remaining (592 user, 592 match max)
        // Actually: User deposits up to 1184, then matching can't add more
        vm.prank(user2);
        uint256 tokenId = tranche.deposit(2000 ether);
        
        // Verify user2 was charged remaining amount, not full 2000
        assertEq(usdt.balanceOf(user2), user2BalanceBefore - remaining);
        
        // Verify note principal matches what was actually deposited
        (, , , , , , uint256 principal, , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(principal, remaining);
        
        // Verify tranche is now full
        (, , , , uint256 totalDeposited, uint256 remainingAfter, , , ) = tranche.getCurrentTranche();
        assertEq(totalDeposited, cap);
        assertEq(remainingAfter, 0);
    }
    
    /**
     * @notice Test Case 4: Tranche full after user deposit - skip matching
     */
    function test_MatchingSkippedWhenTrancheFullAfterDeposit() public {
        // First tranche already started during initialization
        
        uint256 cap = 1584 ether;
        uint256 vaultBalanceBefore = usdt.balanceOf(address(vault));
        
        // User deposits the full cap amount
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(cap);
        
        // User should have token 1
        assertEq(tranche.ownerOf(tokenId), user1);
        
        // Vault balance should be unchanged (no matching occurred)
        assertEq(usdt.balanceOf(address(vault)), vaultBalanceBefore);
        
        // No vault token should exist
        vm.expectRevert(); // ERC721: invalid token ID
        tranche.ownerOf(2);
        
        // Tranche should be full
        (, , , , uint256 totalDeposited, , , , ) = tranche.getCurrentTranche();
        assertEq(totalDeposited, cap);
    }
    
    /**
     * @notice Test Case 5: Matching limited when remaining < matchAmount after user deposit
     */
    function test_MatchingLimitedToRemainingCapacity() public {
        // First tranche already started during initialization
        
        uint256 cap = 1584 ether;
        
        // User deposits 1000, leaving 584 remaining
        // Matching should only get 584 (not 1000)
        uint256 userDeposit = 1000 ether;
        uint256 expectedRemaining = cap - userDeposit; // 584
        
        uint256 vaultBalanceBefore = usdt.balanceOf(address(vault));
        
        vm.prank(user1);
        uint256 userTokenId = tranche.deposit(userDeposit);
        
        // User token should have 1000 principal
        (, , , , , , uint256 userPrincipal, , , , , , , ) = tranche.getNoteInfo(userTokenId);
        assertEq(userPrincipal, userDeposit);
        
        // Vault token should have only 584 (limited by remaining capacity)
        uint256 vaultTokenId = userTokenId + 1;
        (, , , , , , uint256 vaultPrincipal, , , , , , , ) = tranche.getNoteInfo(vaultTokenId);
        assertEq(vaultPrincipal, expectedRemaining);
        
        // Vault should have been charged only 584
        assertEq(usdt.balanceOf(address(vault)), vaultBalanceBefore - expectedRemaining);
        
        // Tranche should be full
        (, , , , uint256 totalDeposited, , , , ) = tranche.getCurrentTranche();
        assertEq(totalDeposited, cap);
    }
    
    /**
     * @notice Test Case 6: Matching uses full amount when sufficient capacity remains
     */
    function test_MatchingFullAmountWhenSufficientCapacity() public {
        // First tranche already started during initialization
        
        uint256 userDeposit = 200 ether;
        uint256 vaultBalanceBefore = usdt.balanceOf(address(vault));
        
        vm.prank(user1);
        uint256 userTokenId = tranche.deposit(userDeposit);
        
        // User should have 200 principal
        (, , , , , , uint256 userPrincipal, , , , , , , ) = tranche.getNoteInfo(userTokenId);
        assertEq(userPrincipal, userDeposit);
        
        // Vault should also have 200 principal (full 1:1 matching)
        uint256 vaultTokenId = userTokenId + 1;
        (, , , , , , uint256 vaultPrincipal, , , , , , , ) = tranche.getNoteInfo(vaultTokenId);
        assertEq(vaultPrincipal, userDeposit);
        
        // Vault should have been charged full amount
        assertEq(usdt.balanceOf(address(vault)), vaultBalanceBefore - userDeposit);
        
        // Total deposited should be 400 (200 + 200)
        (, , , , uint256 totalDeposited, , , , ) = tranche.getCurrentTranche();
        assertEq(totalDeposited, userDeposit * 2);
    }
    
    /**
     * @notice Edge case: MIN_DEPOSIT enforcement on adjusted amount
     * If remaining is less than MIN_DEPOSIT, revert even if requested amount is valid
     */
    function test_RevertWhenRemainingBelowMinDeposit() public {
        // First tranche already started during initialization
        
        uint256 cap = 1584 ether;
        
        // Fill tranche to leave only 50 USDT remaining (below MIN_DEPOSIT of 100)
        // First, user1 deposits enough so remaining is small
        // 1584 - 50 = 1534, but with matching it gets complex
        // Let's fill to exact amount where remaining < 100
        
        // Fill with multiple deposits to get close to cap
        vm.prank(user1);
        tranche.deposit(700 ether); // 700 + 700 match = 1400
        
        (, , , , uint256 afterFirst, , , , ) = tranche.getCurrentTranche();
        assertEq(afterFirst, 1400 ether);
        
        // Remaining is 184 ether - deposit 100 to leave 84 (below MIN_DEPOSIT)
        // 100 user + min(100, 84) match = 100 + 84 = 184 total
        vm.prank(user1);
        tranche.deposit(100 ether);
        
        (, , , , uint256 afterSecond, uint256 remaining, , , ) = tranche.getCurrentTranche();
        // After: 1400 + 100 + 84 = 1584 (full)
        assertEq(afterSecond, cap);
        assertEq(remaining, 0);
        
        // Now any deposit should fail with TrancheFull
        vm.prank(user2);
        vm.expectRevert(DonationTranche.TrancheFull.selector);
        tranche.deposit(200 ether);
    }
    
    /**
     * @notice Edge case: User requests exactly remaining amount
     */
    function test_DepositExactRemainingAmount() public {
        // First tranche already started during initialization
        
        uint256 cap = 1584 ether;
        
        // First deposit to set up specific remaining
        vm.prank(user1);
        tranche.deposit(500 ether); // 500 + 500 match = 1000
        
        (, , , , uint256 afterFirst, uint256 remaining, , , ) = tranche.getCurrentTranche();
        assertEq(afterFirst, 1000 ether);
        assertEq(remaining, 584 ether);
        
        // User2 deposits exactly remaining (584)
        vm.prank(user2);
        uint256 tokenId = tranche.deposit(584 ether);
        
        // User2 gets 584 note
        (, , , , , , uint256 principal, , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(principal, 584 ether);
        
        // No matching because 584 fills the tranche (remaining after = 0)
        vm.expectRevert();
        tranche.ownerOf(tokenId + 1); // No vault token
        
        // Tranche is full
        (, , , , uint256 totalDeposited, , , , ) = tranche.getCurrentTranche();
        assertEq(totalDeposited, cap);
    }
    
    /**
     * @notice Edge case: Vault has insufficient balance - partial matching occurs
     */
    function test_PartialMatchWhenVaultHasLessThanRequired() public {
        // Set up vault with limited funds
        vm.prank(multisig);
        vault.withdraw(); // Empty vault
        
        usdt.mint(address(vault), 100 ether); // Only 100 USDT in vault
        
        // First tranche already started during initialization
        
        uint256 vaultBalanceBefore = usdt.balanceOf(address(vault));
        assertEq(vaultBalanceBefore, 100 ether);
        
        // User deposits 300 - vault can only match 100 (partial match)
        vm.prank(user1);
        uint256 userTokenId = tranche.deposit(300 ether);
        
        // User should have 300
        (, , , , , , uint256 userPrincipal, , , , , , , ) = tranche.getNoteInfo(userTokenId);
        assertEq(userPrincipal, 300 ether);
        
        // Vault should have partial matched (100 USDT available)
        uint256 vaultTokenId = userTokenId + 1;
        (, , , , , , uint256 vaultPrincipal, , , , , , , ) = tranche.getNoteInfo(vaultTokenId);
        assertEq(vaultPrincipal, 100 ether);
        
        // Vault balance should be depleted
        assertEq(usdt.balanceOf(address(vault)), 0);
        
        // Total should be user deposit + partial match
        (, , , , uint256 totalDeposited, , , , uint256 totalMatched) = tranche.getCurrentTranche();
        assertEq(totalDeposited, 400 ether); // 300 + 100
        assertEq(totalMatched, 100 ether);
    }
    
    // ============ Dynamic Minimum Deposit Tests ============
    // Tests for min deposit = (remaining / 2) + 0.001 when remaining < MIN_DEPOSIT * 2
    
    /**
     * @notice Test getEffectiveMinDeposit returns MIN_DEPOSIT when plenty of capacity
     */
    function test_EffectiveMinDeposit_ReturnsMinDepositWhenPlentyCapacity() public {
        // First tranche already started during initialization
        
        // With full tranche capacity (1584 USDT), effective min should be MIN_DEPOSIT
        uint256 effectiveMin = tranche.getEffectiveMinDeposit();
        assertEq(effectiveMin, 100 ether);
    }
    
    /**
     * @notice Test getEffectiveMinDeposit returns half remaining + 0.001 when low capacity
     */
    function test_EffectiveMinDeposit_ReturnsHalfRemainingWhenLowCapacity() public {
        // First tranche already started during initialization
        
        // Fill tranche to leave only 100 USDT remaining (below MIN_DEPOSIT * 2 = 200)
        // 1584 - 100 = 1484 needed
        // User deposits 742, matching adds 742 = 1484 total
        vm.prank(user1);
        tranche.deposit(742 ether);
        
        (, , , , , uint256 remaining, , , ) = tranche.getCurrentTranche();
        assertEq(remaining, 100 ether);
        
        // Effective min should be (100 / 2) + 0.001 = 50.001 ether
        uint256 effectiveMin = tranche.getEffectiveMinDeposit();
        assertEq(effectiveMin, 50 ether + 0.001 ether);
    }
    
    /**
     * @notice Test deposit succeeds with effective minimum when remaining is low
     */
    function test_DepositSucceedsWithEffectiveMinWhenLowCapacity() public {
        // First tranche already started during initialization
        
        // Fill tranche to leave 80 USDT remaining
        // Need 1584 - 80 = 1504 deposited
        // User deposits 752, matching adds 752 = 1504
        vm.prank(user1);
        tranche.deposit(752 ether);
        
        (, , , , , uint256 remaining, , , ) = tranche.getCurrentTranche();
        assertEq(remaining, 80 ether);
        
        // Effective min should be (80 / 2) + 0.001 = 40.001 ether
        uint256 effectiveMin = tranche.getEffectiveMinDeposit();
        assertEq(effectiveMin, 40 ether + 0.001 ether);
        
        // User2 can deposit exactly the effective minimum
        vm.prank(user2);
        uint256 tokenId = tranche.deposit(effectiveMin);
        
        // Verify deposit succeeded
        (, , , , , , uint256 principal, , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(principal, effectiveMin);
    }
    
    /**
     * @notice Test deposit reverts below effective minimum when remaining is low
     */
    function test_DepositRevertsWhenBelowEffectiveMin() public {
        // First tranche already started during initialization
        
        // Fill tranche to leave 80 USDT remaining
        vm.prank(user1);
        tranche.deposit(752 ether);
        
        (, , , , , uint256 remaining, , , ) = tranche.getCurrentTranche();
        assertEq(remaining, 80 ether);
        
        // Effective min is 40.001 ether
        // Try to deposit 40 ether (below effective min)
        vm.prank(user2);
        vm.expectRevert(DonationTranche.BelowMinimumDeposit.selector);
        tranche.deposit(40 ether);
    }
    
    /**
     * @notice Test tranche can be completely filled with dynamic min deposit
     */
    function test_TrancheCanBeCompletelyFilledWithDynamicMin() public {
        // First tranche already started during initialization
        
        uint256 cap = 1584 ether;
        
        // Fill tranche to leave exactly 60 USDT remaining
        // Need 1584 - 60 = 1524 deposited
        // User deposits 762, matching adds 762 = 1524
        vm.prank(user1);
        tranche.deposit(762 ether);
        
        (, , , , , uint256 remaining, , , ) = tranche.getCurrentTranche();
        assertEq(remaining, 60 ether);
        
        // Effective min = (60 / 2) + 0.001 = 30.001 ether
        uint256 effectiveMin = tranche.getEffectiveMinDeposit();
        assertEq(effectiveMin, 30 ether + 0.001 ether);
        
        // User2 deposits exactly half the remaining (30.001)
        // This should fill the tranche: 30.001 user + 29.999 matching = 60
        vm.prank(user2);
        uint256 tokenId = tranche.deposit(effectiveMin);
        
        // Tranche should be full (or very close)
        (, , , , uint256 totalDeposited, uint256 remainingAfter, , , ) = tranche.getCurrentTranche();
        assertEq(totalDeposited, cap);
        assertEq(remainingAfter, 0);
    }
    
    // ============ Expected Match Tests ============
    
    /**
     * @notice Test getExpectedMatch returns full matching when capacity and vault have funds
     */
    function test_GetExpectedMatch_FullMatchWhenCapacityAndVaultAvailable() public {
        // First tranche already started during initialization
        
        uint256 depositAmount = 200 ether;
        
        (uint256 matchAmount, uint256 matchPercentBps) = tranche.getExpectedMatch(depositAmount);
        
        // Full 1:1 matching = 200 ether, 100% = 10000 bps
        assertEq(matchAmount, depositAmount);
        assertEq(matchPercentBps, 10000);
    }
    
    /**
     * @notice Test getExpectedMatch returns partial matching when limited by tranche capacity
     */
    function test_GetExpectedMatch_PartialMatchWhenLimitedByCapacity() public {
        // First tranche already started during initialization
        
        // User deposits 1000, leaving only 584 for matching
        vm.prank(user1);
        tranche.deposit(200 ether); // 200 + 200 = 400 deposited
        
        // Now remaining is 1184
        // If user2 wants to deposit 800, after deposit remaining = 1184 - 800 = 384
        // Matching would be min(800, 384) = 384
        (uint256 matchAmount, uint256 matchPercentBps) = tranche.getExpectedMatch(800 ether);
        
        assertEq(matchAmount, 384 ether);
        // Match percent = 384 / 800 * 10000 = 4800 bps = 48%
        assertEq(matchPercentBps, 4800);
    }
    
    /**
     * @notice Test getExpectedMatch returns zero when deposit would fill tranche
     */
    function test_GetExpectedMatch_ZeroMatchWhenDepositFillsTranche() public {
        // First tranche already started during initialization
        
        uint256 cap = 1584 ether;
        
        // If user deposits full cap, no matching
        (uint256 matchAmount, uint256 matchPercentBps) = tranche.getExpectedMatch(cap);
        
        assertEq(matchAmount, 0);
        assertEq(matchPercentBps, 0);
    }
    
    /**
     * @notice Test getExpectedMatch returns partial when vault has insufficient funds
     */
    function test_GetExpectedMatch_PartialMatchWhenVaultLow() public {
        // Empty vault and add only 50 USDT
        vm.prank(multisig);
        vault.withdraw();
        usdt.mint(address(vault), 50 ether);
        
        // First tranche already started during initialization
        
        // User wants to deposit 200, but vault only has 50
        (uint256 matchAmount, uint256 matchPercentBps) = tranche.getExpectedMatch(200 ether);
        
        assertEq(matchAmount, 50 ether);
        // Match percent = 50 / 200 * 10000 = 2500 bps = 25%
        assertEq(matchPercentBps, 2500);
    }
    
    /**
     * @notice Test getExpectedMatch returns zero when vault is empty
     */
    function test_GetExpectedMatch_ZeroMatchWhenVaultEmpty() public {
        vm.prank(multisig);
        vault.withdraw();
        
        // First tranche already started during initialization
        
        (uint256 matchAmount, uint256 matchPercentBps) = tranche.getExpectedMatch(200 ether);
        
        assertEq(matchAmount, 0);
        assertEq(matchPercentBps, 0);
    }
    
    // ============ Total Matched Tracking Tests ============
    
    /**
     * @notice Test totalMatched is tracked correctly in tranche
     */
    function test_TotalMatchedTrackedInTranche() public {
        // First tranche already started during initialization
        
        // First deposit: 200 user + 200 match
        vm.prank(user1);
        tranche.deposit(200 ether);
        
        (, , , , , uint256 totalMatched1) = tranche.getTranche(1);
        assertEq(totalMatched1, 200 ether);
        
        // Second deposit: 100 user + 100 match
        vm.prank(user2);
        tranche.deposit(100 ether);
        
        (, , , , , uint256 totalMatched2) = tranche.getTranche(1);
        assertEq(totalMatched2, 300 ether);
    }
    
    /**
     * @notice Test totalMatched shows partial matching correctly
     */
    function test_TotalMatchedWithPartialMatching() public {
        // First tranche already started during initialization
        
        // Deposit 1000, matching gets capped to 584 (1584 - 1000)
        vm.prank(user1);
        tranche.deposit(1000 ether);
        
        (, , , , , uint256 totalMatched) = tranche.getTranche(1);
        assertEq(totalMatched, 584 ether);
    }
    
    /**
     * @notice Test totalMatched is zero when no matching occurs
     */
    function test_TotalMatchedZeroWhenNoMatching() public {
        // Empty vault
        vm.prank(multisig);
        vault.withdraw();
        
        // First tranche already started during initialization
        
        vm.prank(user1);
        tranche.deposit(200 ether);
        
        (, , , , , uint256 totalMatched) = tranche.getTranche(1);
        assertEq(totalMatched, 0);
    }
    
    /**
     * @notice Test getCurrentTranche includes totalMatched
     */
    function test_GetCurrentTrancheIncludesTotalMatched() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        tranche.deposit(200 ether);
        
        (, , , , , , , , uint256 totalMatched) = tranche.getCurrentTranche();
        assertEq(totalMatched, 200 ether);
    }
    
    // ============ Tranche Scheduling Tests (New Time Logic) ============
    
    /**
     * @notice Test initialization with future start timestamp
     */
    function test_InitWithFutureStartTimestamp() public {
        // Deploy a new instance with future start
        uint256 futureStart = block.timestamp + 1 days;
        
        DonationTranche trancheImpl = new DonationTranche();
        uint256 currentNonce = vm.getNonce(address(this));
        address predictedProxy = vm.computeCreateAddress(address(this), currentNonce + 1);
        
        DonationMatchVault newVault = new DonationMatchVault(multisig, address(usdt), predictedProxy);
        
        bytes memory initData = abi.encodeWithSelector(
            DonationTranche.initialize.selector,
            address(accessManager),
            address(usdt),
            clusterManager,
            address(newVault),
            futureStart
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(trancheImpl), initData);
        DonationTranche newTranche = DonationTranche(address(proxy));
        
        assertTrue(newTranche.firstTrancheStarted());
        assertEq(newTranche.currentTrancheId(), 1);
        
        (uint256 id, uint256 startTime, uint256 endTime, , , , , , ) = newTranche.getCurrentTranche();
        assertEq(id, 1);
        assertEq(startTime, futureStart);
        assertEq(endTime, futureStart + 2 weeks);
    }
    
    /**
     * @notice Test scheduleAdditionalTranches with fixed 2-week duration
     */
    function test_ScheduleTranches() public {
        // Start first tranche
        // First tranche already started during initialization
        
        // Schedule 3 more tranches
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(3, 0, 0); // count=3, start=0 (auto)
        
        // Get scheduled tranches
        (uint256[] memory startTimes, uint256[] memory endTimes, ) = tranche.getScheduledTranches();
        
        // Should have existing 5 + new 3 = 8 scheduled (minus 1 for current = 7 waiting)
        // Actually: initial 6, start first uses 1, so 5 remaining. Add 3 = 8.
        assertEq(startTimes.length, 8);
        
        // First scheduled should start at current tranche end
        (, , uint256 currentEnd, , , , , , ) = tranche.getCurrentTranche();
        assertEq(startTimes[0], currentEnd);
        
        // Each subsequent should be 2 weeks apart
        for (uint256 i = 1; i < startTimes.length; i++) {
            assertEq(startTimes[i], startTimes[i-1] + 2 weeks);
        }
    }
    
    /**
     * @notice Test scheduleAdditionalTranches with explicit startOverride
     */
    function test_ScheduleTranchesWithStartOverride() public {
        // First tranche already started during initialization
        
        // Get the last scheduled tranche time to ensure new ones don't overlap
        (uint256[] memory beforeTimes, , ) = tranche.getScheduledTranches();
        uint256 lastScheduled = beforeTimes[beforeTimes.length - 1];
        
        // Schedule tranches with explicit start time after last scheduled + 2 weeks
        uint256 explicitStart = lastScheduled + 2 weeks;
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(2, explicitStart, 0);
        
        (uint256[] memory startTimes, , ) = tranche.getScheduledTranches();
        
        // Last two should start at explicitStart and explicitStart + 2 weeks
        uint256 len = startTimes.length;
        assertEq(startTimes[len-2], explicitStart);
        assertEq(startTimes[len-1], explicitStart + 2 weeks);
    }
    
    /**
     * @notice Test scheduleAdditionalTranches with 0 start uses back() + TRANCHE_DURATION when pending exist
     */
    function test_ScheduleTranchesZeroStartWithPending() public {
        // First tranche already started during initialization
        
        // Get initial scheduled tranches
        (uint256[] memory beforeTimes, , ) = tranche.getScheduledTranches();
        uint256 lastScheduled = beforeTimes[beforeTimes.length - 1];
        
        // Schedule more with 0 start - should continue from last scheduled
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(1, 0, 0);
        
        (uint256[] memory afterTimes, , ) = tranche.getScheduledTranches();
        uint256 newlyScheduled = afterTimes[afterTimes.length - 1];
        
        // New tranche should start at lastScheduled + 2 weeks
        assertEq(newlyScheduled, lastScheduled + 2 weeks);
    }
    
    /**
     * @notice Test scheduleAdditionalTranches with 0 start uses block.timestamp when all ended
     * @dev Tests the case when all tranches are exhausted and queue is empty
     */
    function test_ScheduleTranchesZeroStartActiveTranche() public {
        // First tranche already started during initialization
        
        // Exhaust all scheduled tranches by progressing through them
        for (uint256 i = 1; i <= 6; i++) {
            // Make a deposit in current tranche
            vm.prank(user1);
            tranche.deposit(100 ether);
            
            // Fast forward past tranche end
            skip(2 weeks + 1);
            
            // Collect the tranche
            tranche.collectTranche(i);
            
            // If not the last tranche, deposit to trigger next
            if (i < 6) {
                vm.prank(user1);
                tranche.deposit(100 ether);
            }
        }
        
        // All exhausted, queue is empty
        assertEq(tranche.scheduledTrancheCount(), 0);
        assertEq(tranche.currentTrancheId(), 6);
        
        uint256 currentTime = block.timestamp;
        
        // Schedule 1 more - uses block.timestamp since all ended and queue empty
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(1, 0, 0);
        
        (uint256[] memory times, , ) = tranche.getScheduledTranches();
        assertEq(times.length, 1);
        assertEq(times[0], currentTime); // Should use current timestamp
    }
    
    /**
     * @notice Test scheduleAdditionalTranches with 0 start uses block.timestamp when all ended
     */
    function test_ScheduleTranchesZeroStartAllEnded() public {
        // First tranche already started during initialization
        
        // Exhaust all tranches by progressing through them
        for (uint256 i = 1; i <= 6; i++) {
            vm.prank(user1);
            tranche.deposit(100 ether);
            
            skip(2 weeks + 1);
            tranche.collectTranche(i);
            
            if (i < 6) {
                vm.prank(user1);
                tranche.deposit(100 ether);
            }
        }
        
        uint256 currentTime = block.timestamp;
        
        // Schedule more - should start from current time
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(2, 0, 0);
        
        (uint256[] memory times, , ) = tranche.getScheduledTranches();
        assertEq(times[0], currentTime);
        assertEq(times[1], currentTime + 2 weeks);
    }
    
    /**
     * @notice Test revert when initializing with past timestamp
     */
    function test_RevertInitWithPastTimestamp() public {
        // Warp time forward so past time isn't 0 (which gets converted to block.timestamp)
        vm.warp(1000);
        uint256 pastTime = block.timestamp - 1;
        
        DonationTranche trancheImpl = new DonationTranche();
        uint256 currentNonce = vm.getNonce(address(this));
        address predictedProxy = vm.computeCreateAddress(address(this), currentNonce + 1);
        
        DonationMatchVault newVault = new DonationMatchVault(multisig, address(usdt), predictedProxy);
        
        bytes memory initData = abi.encodeWithSelector(
            DonationTranche.initialize.selector,
            address(accessManager),
            address(usdt),
            clusterManager,
            address(newVault),
            pastTime
        );
        
        vm.expectRevert(DonationTranche.InvalidStartTime.selector);
        new ERC1967Proxy(address(trancheImpl), initData);
    }
    
    /**
     * @notice Test revert when scheduleAdditionalTranches with past startOverride
     */
    function test_RevertScheduleStartOverridePast() public {
        // Advance time so we have a meaningful "past" time (not 0)
        vm.warp(1000);
        
        // First tranche already started during initialization
        
        // Warp forward so "past" time is clearly in the past
        skip(1 days);
        
        uint256 pastTime = block.timestamp - 1 hours; // 1 hour in the past
        
        vm.prank(admin);
        vm.expectRevert(DonationTranche.InvalidStartTime.selector);
        tranche.scheduleAdditionalTranches(1, pastTime, 0);
    }
    
    /**
     * @notice Test getScheduledTranches returns correct data
     */
    function test_GetScheduledTranches() public {
        // First tranche already started during initialization
        
        (uint256[] memory startTimes, uint256[] memory endTimes, ) = tranche.getScheduledTranches();
        
        // Should have 5 scheduled (6 initial - 1 started)
        assertEq(startTimes.length, 5);
        assertEq(endTimes.length, 5);
        
        // Each endTime should be startTime + 2 weeks
        for (uint256 i = 0; i < startTimes.length; i++) {
            assertEq(endTimes[i], startTimes[i] + 2 weeks);
        }
    }
    
    // ============ Tranche Cap Tests ============
    
    /**
     * @notice Test setDefaultTrancheCap changes default for new tranches
     */
    function test_SetDefaultTrancheCap() public {
        uint256 newCap = 5000 ether;
        
        vm.prank(admin);
        tranche.setDefaultTrancheCap(newCap);
        
        assertEq(tranche.defaultTrancheCap(), newCap);
        
        // First tranche was created during init with original cap
        (, , , uint256 firstCap, , , , , ) = tranche.getCurrentTranche();
        assertEq(firstCap, 1584 ether); // Original cap
        
        // Progress to next tranche - it should use the new cap
        skip(2 weeks + 1);
        tranche.collectTranche(1);
        
        vm.prank(user1);
        tranche.deposit(100 ether); // Triggers next tranche
        
        // New tranche should have the new default cap
        (, , , uint256 newTrancheCap, , , , , ) = tranche.getCurrentTranche();
        assertEq(newTrancheCap, newCap);
    }
    
    /**
     * @notice Test setTrancheCap updates specific tranche cap
     */
    function test_SetTrancheCap() public {
        // First tranche already started during initialization
        
        uint256 newCap = 3000 ether;
        
        vm.prank(admin);
        tranche.setTrancheCap(1, newCap);
        
        (, , , uint256 cap, , , , , ) = tranche.getCurrentTranche();
        assertEq(cap, newCap);
    }
    
    /**
     * @notice Test setTrancheCap cannot set below totalDeposited
     */
    function test_RevertSetTrancheCapBelowDeposited() public {
        // First tranche already started during initialization
        
        // Deposit 500 USDT
        vm.prank(user1);
        tranche.deposit(500 ether); // 500 + 500 match = 1000 deposited
        
        // Try to set cap below deposited amount
        vm.prank(admin);
        vm.expectRevert(DonationTranche.CapBelowDeposited.selector);
        tranche.setTrancheCap(1, 500 ether);
    }
    
    /**
     * @notice Test setTrancheCap reverts for nonexistent tranche
     */
    function test_RevertSetTrancheCapNonexistent() public {
        // First tranche already started during initialization
        
        vm.prank(admin);
        vm.expectRevert(DonationTranche.TrancheNonexistant.selector);
        tranche.setTrancheCap(99, 5000 ether);
    }
    
    /**
     * @notice Test scheduleAdditionalTranches with custom cap
     */
    function test_ScheduleTranchesWithCustomCap() public {
        // First tranche already started during initialization
        
        uint256 customCap = 10000 ether;
        
        // Schedule 2 tranches with custom cap
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(2, 0, customCap);
        
        // Get scheduled tranches info
        (uint256[] memory startTimes, , uint256[] memory caps) = tranche.getScheduledTranches();
        
        // The last 2 should have custom cap
        uint256 len = startTimes.length;
        assertEq(caps[len - 1], customCap);
        assertEq(caps[len - 2], customCap);
    }
    
    /**
     * @notice Test scheduleAdditionalTranches with 0 cap uses default
     */
    function test_ScheduleTranchesZeroCapUsesDefault() public {
        // First tranche already started during initialization
        
        // Schedule with 0 cap (should use default)
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(1, 0, 0);
        
        (uint256[] memory startTimes, , uint256[] memory caps) = tranche.getScheduledTranches();
        
        uint256 len = startTimes.length;
        assertEq(caps[len - 1], 1584 ether); // INITIAL_TRANCHE_CAP (default)
    }
    
    /**
     * @notice Test new tranche uses scheduled cap
     */
    function test_NewTrancheUsesScheduledCap() public {
        // First tranche already started during initialization
        
        // Schedule tranches with custom cap
        uint256 customCap = 8000 ether;
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(1, 0, customCap);
        
        // Progress through initial scheduled tranches
        for (uint256 i = 1; i <= 5; i++) {
            vm.prank(user1);
            tranche.deposit(100 ether);
            skip(2 weeks + 1);
            tranche.collectTranche(i);
        }
        
        // Last initial tranche
        vm.prank(user1);
        tranche.deposit(100 ether);
        skip(2 weeks + 1);
        tranche.collectTranche(6);
        
        // Next deposit should trigger the custom cap tranche
        vm.prank(user1);
        tranche.deposit(100 ether);
        
        (, , , uint256 cap, , , , , ) = tranche.getCurrentTranche();
        assertEq(cap, customCap);
    }
    
    // ============ Public Start Next Tranche Tests ============
    
    /**
     * @notice Test anyone can call startNextTranche when conditions are met
     */
    function test_PublicStartNextTranche() public {
        // First tranche already started during initialization
        
        // Make deposit and wait for tranche to end
        vm.prank(user1);
        tranche.deposit(100 ether);
        
        skip(2 weeks + 1);
        tranche.collectTranche(1);
        
        // Anyone can start next tranche (not just admin)
        vm.prank(user2); // Regular user, not admin
        tranche.startNextTranche();
        
        assertEq(tranche.currentTrancheId(), 2);
    }
    
    /**
     * @notice Test startNextTranche respects scheduled time for non-admin
     */
    function test_PublicStartNextTrancheRespectsScheduledTime() public {
        // First tranche already started during initialization
        
        // Fill and collect tranche 1
        vm.prank(user1);
        tranche.deposit(1584 ether); // Fill completely
        
        tranche.collectTranche(1);
        
        // Tranche 2 is scheduled to start at tranche 1's end time
        // Since we collected early (before 2 weeks), scheduled time hasn't arrived
        // Regular user should not be able to start early
        vm.prank(user2);
        vm.expectRevert(DonationTranche.ScheduledTimeNotReached.selector);
        tranche.startNextTranche();
        
        // Wait until scheduled time
        skip(2 weeks);
        
        // Now anyone can start
        vm.prank(user2);
        tranche.startNextTranche();
        
        assertEq(tranche.currentTrancheId(), 2);
    }
    
    /**
     * @notice Test admin can still start early with adminStartNextTranche
     */
    function test_AdminCanStartTrancheEarly() public {
        // First tranche already started during initialization
        
        // Fill and collect tranche 1 early
        vm.prank(user1);
        tranche.deposit(1584 ether);
        
        tranche.collectTranche(1);
        
        // Admin can start early
        vm.prank(admin);
        tranche.adminStartNextTranche();
        
        assertEq(tranche.currentTrancheId(), 2);
        
        // Verify it started at current time (early)
        (, uint256 startTime, , , , , , , ) = tranche.getCurrentTranche();
        assertEq(startTime, block.timestamp);
    }
    
    // ============ Early Collection Tests ============
    
    /**
     * @notice Test collecting a full tranche before endTime
     */
    function test_CollectFullTrancheBeforeEndTime() public {
        // First tranche already started during initialization
        
        uint256 cap = 1584 ether;
        
        // Fill tranche completely
        vm.prank(user1);
        tranche.deposit(cap);
        
        // Verify tranche is full but time hasn't ended
        (, , uint256 endTime, , uint256 totalDeposited, uint256 remaining, , , ) = tranche.getCurrentTranche();
        assertEq(totalDeposited, cap);
        assertEq(remaining, 0);
        assertTrue(block.timestamp < endTime); // Not yet ended by time
        
        uint256 managerBalanceBefore = usdt.balanceOf(clusterManager);
        
        // Should be able to collect even though time hasn't ended
        tranche.collectTranche(1);
        
        // Verify collection succeeded
        assertEq(usdt.balanceOf(clusterManager), managerBalanceBefore + cap);
        
        (, , , , bool collected, ) = tranche.getTranche(1);
        assertTrue(collected);
    }
    
    /**
     * @notice Test cannot collect partial tranche before endTime
     */
    function test_CannotCollectPartialTrancheBeforeEndTime() public {
        // First tranche already started during initialization
        
        // Partial deposit
        vm.prank(user1);
        tranche.deposit(500 ether);
        
        // Tranche is not full and time hasn't ended
        (, , uint256 endTime, , , uint256 remaining, , , ) = tranche.getCurrentTranche();
        assertTrue(remaining > 0);
        assertTrue(block.timestamp < endTime);
        
        // Should revert - not full and not ended
        vm.expectRevert(DonationTranche.TrancheNotEnded.selector);
        tranche.collectTranche(1);
    }
    
    // ============ Auto-Progression Tests ============
    
    /**
     * @notice Test deposit auto-progresses to next tranche after time elapsed
     */
    function test_DepositToNextTrancheAfterTimeElapsed() public {
        // First tranche already started during initialization
        
        // Make initial deposit
        vm.prank(user1);
        tranche.deposit(200 ether);
        
        // Fast forward past tranche end
        skip(2 weeks + 1);
        
        // Deposit should trigger progression to next tranche
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(200 ether);
        
        // Should be in tranche 2 now
        assertEq(tranche.currentTrancheId(), 2);
        
        // New deposit should be in tranche 2
        (, uint256 noteTrancheId, , , , , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(noteTrancheId, 2);
    }
    
    /**
     * @notice Test deposit auto-collects previous tranche if not collected
     */
    function test_DepositAutoCollectsPreviousTranche() public {
        // First tranche already started during initialization
        
        // Deposit in tranche 1
        vm.prank(user1);
        tranche.deposit(200 ether); // 200 + 200 match = 400
        
        uint256 tranche1Deposited = 400 ether;
        uint256 managerBalanceBefore = usdt.balanceOf(clusterManager);
        
        // Fast forward past tranche 1 end
        skip(2 weeks + 1);
        
        // Tranche 1 not manually collected
        (, , , , bool collected1Before, ) = tranche.getTranche(1);
        assertFalse(collected1Before);
        
        // Deposit to next tranche - should auto-collect tranche 1
        vm.prank(user1);
        tranche.deposit(200 ether);
        
        // Tranche 1 should now be collected
        (, , , , bool collected1After, ) = tranche.getTranche(1);
        assertTrue(collected1After);
        
        // Cluster manager should have received tranche 1 funds
        assertEq(usdt.balanceOf(clusterManager), managerBalanceBefore + tranche1Deposited);
    }
    
    /**
     * @notice Test tranches progress automatically without manual admin start
     */
    function test_TrancheProgressionWithoutManualStart() public {
        // First tranche already started during initialization
        
        // Progress through multiple tranches just by depositing after time elapses
        for (uint256 i = 1; i <= 3; i++) {
            vm.prank(user1);
            tranche.deposit(100 ether);
            
            assertEq(tranche.currentTrancheId(), i);
            
            // Fast forward past current tranche
            skip(2 weeks + 1);
        }
        
        // Make another deposit - should auto-progress to tranche 4
        vm.prank(user1);
        tranche.deposit(100 ether);
        
        assertEq(tranche.currentTrancheId(), 4);
    }
    
    /**
     * @notice Test getCurrentTranche returns correct tranche based on time
     */
    function test_GetCurrentTrancheReturnsCorrectByTime() public {
        // First tranche already started during initialization
        
        // Initially should be tranche 1
        (uint256 id1, , , , , , bool isActive1, , ) = tranche.getCurrentTranche();
        assertEq(id1, 1);
        assertTrue(isActive1);
        
        // Fast forward past tranche 1 end
        skip(2 weeks + 1);
        
        // getCurrentTranche should still show tranche 1 as current (but inactive)
        // because we haven't triggered progression yet
        (uint256 id2, , , , , , bool isActive2, , ) = tranche.getCurrentTranche();
        assertEq(id2, 1);
        assertFalse(isActive2); // Should be inactive (ended by time)
    }
    
    /**
     * @notice Test scheduledTrancheCount returns correct count
     */
    function test_ScheduledTrancheCount() public {
        // First tranche already started during initialization
        
        // After starting first tranche, should have 5 scheduled
        assertEq(tranche.scheduledTrancheCount(), 5);
        
        // Schedule more
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(3, 0, 0);
        
        assertEq(tranche.scheduledTrancheCount(), 8);
    }
}

contract DonationMatchVaultTest is Test {
    DonationMatchVault public vault;
    MockUSDT public usdt;
    
    address public multisig = address(1);
    address public user = address(2);
    address public dummyTranche = address(100);
    
    function setUp() public {
        usdt = new MockUSDT();
        vault = new DonationMatchVault(multisig, address(usdt), dummyTranche);
        
        // Fund vault
        usdt.mint(address(vault), 1000 ether);
    }
    
    function test_AutoApprovalDuringConstruction() public view {
        // Vault should have pre-approved the donationTranche for 17,500 USDT
        assertEq(usdt.allowance(address(vault), dummyTranche), 17_500 ether);
    }
    
    function test_InitialState() public view {
        assertEq(vault.owner(), multisig);
        assertEq(address(vault.usdt()), address(usdt));
        assertEq(vault.getBalance(), 1000 ether);
    }
    
    function test_Withdraw() public {
        vm.prank(multisig);
        vault.withdraw();
        
        assertEq(usdt.balanceOf(multisig), 1000 ether);
        assertEq(vault.getBalance(), 0);
    }
    
    function test_RevertWithdrawNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        vault.withdraw();
    }
    
    function test_ApproveUsdt() public {
        address spender = address(100);
        
        vm.prank(multisig);
        vault.approveUsdt(spender, 500 ether);
        
        assertEq(usdt.allowance(address(vault), spender), 500 ether);
    }
    
    function test_ReceiveNFT() public {
        // Create a simple ERC721 to test receiving
        // The vault should accept any ERC721
        bytes4 selector = vault.onERC721Received(address(this), user, 1, "");
        assertEq(selector, IERC721Receiver.onERC721Received.selector);
    }
}
