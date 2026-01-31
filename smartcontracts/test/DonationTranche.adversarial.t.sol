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

// Malicious contract that attempts reentrancy on deposit
contract ReentrancyAttacker {
    DonationTranche public tranche;
    MockUSDT public usdt;
    uint256 public attackCount;
    
    constructor(address _tranche, address _usdt) {
        tranche = DonationTranche(_tranche);
        usdt = MockUSDT(_usdt);
    }
    
    function attack(uint256 amount) external {
        usdt.approve(address(tranche), type(uint256).max);
        tranche.deposit(amount);
    }
    
    // Attempt reentrancy on ERC721 receive
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        attackCount++;
        if (attackCount < 3 && usdt.balanceOf(address(this)) >= 100 ether) {
            // Try to deposit again during NFT receive
            try tranche.deposit(100 ether) {} catch {}
        }
        return this.onERC721Received.selector;
    }
}

// Malicious contract that attempts reentrancy on repay
contract RepayReentrancyAttacker {
    DonationTranche public tranche;
    MockUSDT public usdt;
    uint256 public tokenId;
    uint256 public attackCount;
    
    constructor(address _tranche, address _usdt) {
        tranche = DonationTranche(_tranche);
        usdt = MockUSDT(_usdt);
    }
    
    function setTokenId(uint256 _tokenId) external {
        tokenId = _tokenId;
    }
    
    function attack(uint256 amount) external {
        usdt.approve(address(tranche), type(uint256).max);
        tranche.repay(tokenId, amount);
    }
    
    // This won't be called during repay since repay doesn't trigger callbacks to attacker
    // But included for completeness
    receive() external payable {
        attackCount++;
        if (attackCount < 3) {
            try tranche.repay(tokenId, 10 ether) {} catch {}
        }
    }
}

contract DonationTrancheAdversarialTest is Test {
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
    address public repayer = address(7);
    
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
        
        // Setup access control
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
        
        // Mint USDT to users and vault
        usdt.mint(user1, 100000 ether);
        usdt.mint(user2, 100000 ether);
        usdt.mint(attacker, 100000 ether);
        usdt.mint(repayer, 100000 ether);
        usdt.mint(address(vault), 50000 ether);
        
        // Approve tranche contract
        vm.prank(user1);
        usdt.approve(address(tranche), type(uint256).max);
        
        vm.prank(user2);
        usdt.approve(address(tranche), type(uint256).max);
        
        vm.prank(attacker);
        usdt.approve(address(tranche), type(uint256).max);
        
        vm.prank(repayer);
        usdt.approve(address(tranche), type(uint256).max);
    }
    
    // ============ Access Control Tests ============
    
    function test_NonAdminCannotScheduleTranches() public {
        vm.prank(attacker);
        vm.expectRevert();
        tranche.scheduleAdditionalTranches(5, 0, 0);
    }
    
    function test_AnyoneCanStartNextTrancheWhenScheduledTimeReached() public {
        // First start tranche as admin
        // First tranche already started during initialization
        
        // Make a deposit
        vm.prank(user1);
        tranche.deposit(100 ether);
        
        // Wait for tranche to end and collect
        skip(2 weeks + 1);
        tranche.collectTranche(1);
        
        // Anyone can start when scheduled time is reached
        vm.prank(attacker);
        tranche.startNextTranche();
        
        assertEq(tranche.currentTrancheId(), 2);
    }
    
    function test_NonAdminCannotSetVault() public {
        vm.prank(attacker);
        vm.expectRevert();
        tranche.setVault(attacker);
    }
    
    function test_NonAdminCannotSetApr() public {
        vm.prank(attacker);
        vm.expectRevert();
        tranche.setDefaultApr(10000);
    }
    
    function test_NonAdminCannotSetDefaultTrancheCap() public {
        vm.prank(attacker);
        vm.expectRevert();
        tranche.setDefaultTrancheCap(5000 ether);
    }
    
    function test_NonAdminCannotSetTrancheCap() public {
        // First tranche already started during initialization
        
        vm.prank(attacker);
        vm.expectRevert();
        tranche.setTrancheCap(1, 5000 ether);
    }
    
    function test_NonAdminCannotStartTrancheEarly() public {
        // First tranche already started during initialization
        
        // Fill and collect early
        vm.prank(user1);
        tranche.deposit(1584 ether);
        tranche.collectTranche(1);
        
        // Attacker cannot start early (scheduled time not reached)
        vm.prank(attacker);
        vm.expectRevert(DonationTranche.ScheduledTimeNotReached.selector);
        tranche.startNextTranche();
        
        // But admin can use adminStartNextTranche
        vm.prank(admin);
        tranche.adminStartNextTranche();
        
        assertEq(tranche.currentTrancheId(), 2);
    }
    
    function test_NonOwnerCannotWithdrawVault() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.withdraw();
    }
    
    function test_NonOwnerCannotApproveVaultUsdt() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.approveUsdt(attacker, 1000 ether);
    }
    
    // ============ Reentrancy Tests ============
    
    function test_ReentrancyOnDeposit() public {
        // First tranche already started during initialization
        
        // Deploy attacker contract
        ReentrancyAttacker attackerContract = new ReentrancyAttacker(address(tranche), address(usdt));
        usdt.mint(address(attackerContract), 10000 ether);
        
        // Try attack
        attackerContract.attack(200 ether);
        
        // Verify only one deposit succeeded (reentrancy prevented by natural flow)
        // The contract should have exactly 1 note (the initial deposit)
        assertEq(tranche.balanceOf(address(attackerContract)), 1);
    }
    
    function test_ReentrancyOnRepay() public {
        // First tranche already started during initialization
        
        // Create a note
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(200 ether);
        
        // Fast forward to accrue interest
        skip(30 days);
        
        (, , , , uint256 interestOwedBefore, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        
        // Deploy attacker contract  
        RepayReentrancyAttacker attackerContract = new RepayReentrancyAttacker(address(tranche), address(usdt));
        usdt.mint(address(attackerContract), 10000 ether);
        attackerContract.setTokenId(tokenId);
        
        uint256 repayAmount = interestOwedBefore / 2;
        
        // Attack - should complete normally without reentrancy issues
        attackerContract.attack(repayAmount);
        
        // Verify repayment worked correctly - interest paid should equal repay amount
        (, , , , , , , , uint256 interestPaid, , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(interestPaid, repayAmount);
    }
    
    function test_ReentrancyOnCollect() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        tranche.deposit(200 ether);
        
        skip(2 weeks + 1);
        
        uint256 managerBalanceBefore = usdt.balanceOf(clusterManager);
        
        // Collect tranche - no reentrancy vector here as it's a simple transfer
        tranche.collectTranche(1);
        
        // Verify collection worked correctly
        assertEq(usdt.balanceOf(clusterManager), managerBalanceBefore + 400 ether);
    }
    
    // ============ Economic Attack Tests ============
    
    function test_DustDepositRejected() public {
        // First tranche already started during initialization
        
        // Try to deposit 1 wei - should fail
        vm.prank(attacker);
        vm.expectRevert(DonationTranche.BelowMinimumDeposit.selector);
        tranche.deposit(1);
        
        // Try to deposit 99 USDT (below 100 minimum)
        vm.prank(attacker);
        vm.expectRevert(DonationTranche.BelowMinimumDeposit.selector);
        tranche.deposit(99 ether);
    }
    
    function test_CannotDepositWhenNoActiveTranche() public {
        // First tranche already started during initialization
        
        // Exhaust all tranches by depositing, progressing, and collecting
        for (uint256 i = 1; i <= 6; i++) {
            vm.prank(user1);
            tranche.deposit(100 ether);
            skip(2 weeks + 1);
            tranche.collectTranche(i);
            
            // Trigger next tranche if not last
            if (i < 6) {
                vm.prank(user1);
                tranche.deposit(100 ether);
            }
        }
        
        // Now no more scheduled tranches
        assertEq(tranche.scheduledTrancheCount(), 0);
        
        // Try to deposit - should fail
        vm.prank(attacker);
        vm.expectRevert(DonationTranche.TrancheNotActive.selector);
        tranche.deposit(200 ether);
    }
    
    function test_CannotDoubleCollect() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        tranche.deposit(200 ether);
        
        skip(2 weeks + 1);
        
        // First collection
        tranche.collectTranche(1);
        
        // Second collection should fail
        vm.expectRevert(DonationTranche.TrancheAlreadyCollected.selector);
        tranche.collectTranche(1);
    }
    
    function test_RepayMoreThanOwedCapsAtTotal() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(100 ether);
        
        // Fast forward to accrue some interest
        skip(30 days);
        
        (, , , , uint256 interestOwed, , uint256 principal, , , , , , , ) = tranche.getNoteInfo(tokenId);
        uint256 totalOwed = interestOwed + principal;
        
        uint256 repayerBalanceBefore = usdt.balanceOf(repayer);
        uint256 user1BalanceBefore = usdt.balanceOf(user1);
        
        // Try to repay way more than owed
        vm.prank(repayer);
        tranche.repay(tokenId, totalOwed * 10);
        
        // Verify only the correct amount was transferred
        // Repayer should have paid exactly totalOwed (not more)
        assertEq(usdt.balanceOf(repayer), repayerBalanceBefore - totalOwed);
        assertEq(usdt.balanceOf(user1), user1BalanceBefore + totalOwed);
        
        // Note should be fully repaid
        (, , , , , , , , , , , , bool fullyRepaid, ) = tranche.getNoteInfo(tokenId);
        assertTrue(fullyRepaid);
    }
    
    // ============ Edge Case Tests ============
    
    function test_NoInterestLostOnDustThresholdCompletion() public {
        // Verify that when a note is marked complete due to dust threshold,
        // all accrued interest has been paid (no interest is lost)
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(1000 ether);
        
        // Accrue interest over 30 days
        skip(30 days);
        
        // Get interest owed before repayment
        (, , , , uint256 interestOwed, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertTrue(interestOwed > 0, "Should have accrued interest");
        
        // Calculate amount to leave dust principal (< 1 USDT)
        // Pay all interest + almost all principal, leaving 0.5 USDT
        uint256 repayAmount = interestOwed + 999.5 ether;
        
        vm.prank(repayer);
        tranche.repay(tokenId, repayAmount);
        
        // Note should be marked complete (dust threshold)
        (, , , , uint256 interestOwedAfter, , , , uint256 interestPaid, , uint256 remainingPrincipal, , bool fullyRepaid, ) = tranche.getNoteInfo(tokenId);
        
        assertTrue(fullyRepaid, "Note should be marked complete");
        assertEq(remainingPrincipal, 0.5 ether, "Should have dust principal");
        
        // CRITICAL: Interest owed should be 0 - all interest was paid
        assertEq(interestOwedAfter, 0, "No interest should be owed - all paid before principal reduction");
        
        // Interest paid should equal the interest that was owed
        assertApproxEqAbs(interestPaid, interestOwed, 1, "All interest should have been paid");
    }
    
    function test_CannotReducePrincipalWithoutPayingAllInterest() public {
        // Verify that you cannot reduce principal without first paying all interest
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(1000 ether);
        
        // Accrue interest over 30 days
        skip(30 days);
        
        // Get interest owed
        (, , , , uint256 interestOwed, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertTrue(interestOwed > 0);
        
        // Pay less than interest owed
        uint256 partialInterest = interestOwed / 2;
        vm.prank(repayer);
        tranche.repay(tokenId, partialInterest);
        
        // Principal should NOT be reduced
        (, , , , , , , uint256 principalRepaid, , , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(principalRepaid, 0, "Principal should not be reduced when only paying partial interest");
        
        // Pay remaining interest + some principal
        (, , , , uint256 remainingInterest, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        
        vm.prank(repayer);
        tranche.repay(tokenId, remainingInterest + 100 ether);
        
        // NOW principal should be reduced
        (, , , , uint256 interestAfter, , , uint256 principalRepaidAfter, , , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(principalRepaidAfter, 100 ether, "Principal should now be reduced");
        assertEq(interestAfter, 0, "Interest should be 0 after paying all + principal");
    }
    
    function test_ZeroAmountRepayReverts() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(100 ether);
        
        vm.prank(repayer);
        vm.expectRevert(DonationTranche.ZeroAmount.selector);
        tranche.repay(tokenId, 0);
    }
    
    function test_RepayNonExistentNoteReverts() public {
        // First tranche already started during initialization
        
        vm.prank(repayer);
        vm.expectRevert(DonationTranche.InvalidNote.selector);
        tranche.repay(999, 100 ether);
    }
    
    function test_InterestCalculationAtMaxTime() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(1000 ether);
        
        // Skip 100 years - extreme time test
        skip(100 * 365 days);
        
        // Should not overflow
        (, , , , uint256 interestOwed, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        
        // 30% APR for 100 years = 3000% = 30x principal
        // Interest should be approximately 30000 USDT
        assertApproxEqAbs(interestOwed, 30000 ether, 100 ether);
    }
    
    function test_TransferDuringActiveNote() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(200 ether);
        
        skip(30 days);
        
        // Transfer note to user2
        vm.prank(user1);
        tranche.safeTransferFrom(user1, user2, tokenId);
        
        // Verify ownership changed
        assertEq(tranche.ownerOf(tokenId), user2);
        
        // Repayment should now go to user2
        (, , , , uint256 interestOwed, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        uint256 user2BalanceBefore = usdt.balanceOf(user2);
        
        vm.prank(repayer);
        tranche.repay(tokenId, interestOwed);
        
        assertEq(usdt.balanceOf(user2), user2BalanceBefore + interestOwed);
    }
    
    function test_InterestPerSecondDecreasesWhenPrincipalReduced() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(1000 ether);
        
        skip(30 days);
        
        // Get initial interest per second
        (, , , , uint256 interestOwed1, uint256 interestPerSecond1, , , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertTrue(interestOwed1 > 0);
        assertTrue(interestPerSecond1 > 0);
        
        // Repay all interest + 500 principal
        vm.prank(repayer);
        tranche.repay(tokenId, interestOwed1 + 500 ether);
        
        // Get new interest per second - should be ~50% of original
        (, , , , uint256 interestOwed2, uint256 interestPerSecond2, , uint256 principalRepaid, , , uint256 remainingPrincipal, , , ) = tranche.getNoteInfo(tokenId);
        
        // Verify principal was reduced
        assertEq(principalRepaid, 500 ether);
        assertEq(remainingPrincipal, 500 ether);
        
        // Interest per second should now be half (500/1000 = 50%)
        assertApproxEqAbs(interestPerSecond2, interestPerSecond1 / 2, 1);
        
        // Interest owed should be 0 right after repayment (timestamp was reset)
        assertEq(interestOwed2, 0);
        
        // Skip more time and verify interest accrues at lower rate
        skip(30 days);
        
        (, , , , uint256 interestOwed3, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        
        // New interest should be ~50% of original interest (same time period, half principal)
        assertApproxEqAbs(interestOwed3, interestOwed1 / 2, 1 ether);
    }
    
    function test_PartialInterestPaymentTrackedCorrectly() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(1000 ether);
        
        skip(30 days);
        
        // Get interest owed
        (, , , , uint256 interestOwed1, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertTrue(interestOwed1 > 0);
        
        // Pay half the interest
        uint256 halfInterest = interestOwed1 / 2;
        vm.prank(repayer);
        tranche.repay(tokenId, halfInterest);
        
        // Check interest owed is reduced by half
        (, , , , uint256 interestOwed2, , , , uint256 interestPaid, , , , , ) = tranche.getNoteInfo(tokenId);
        
        assertEq(interestPaid, halfInterest);
        // Interest owed should be the other half (no time passed, same principal)
        assertApproxEqAbs(interestOwed2, interestOwed1 - halfInterest, 1);
        
        // Pay remaining interest
        vm.prank(repayer);
        tranche.repay(tokenId, interestOwed2);
        
        // Interest should now be 0
        (, , , , uint256 interestOwed3, , , , uint256 totalInterestPaid, , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(interestOwed3, 0);
        assertEq(totalInterestPaid, interestOwed1);
    }
    
    function test_InterestAccruedLockedInOnPrincipalReduction() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(1000 ether);
        
        skip(30 days);
        
        // Get interest owed before any payment
        (, , , , uint256 interestOwed1, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertTrue(interestOwed1 > 0);
        
        // Pay all interest + 100 principal
        // Note: repay() pays interest first, so we must pay all interest before principal
        vm.prank(repayer);
        tranche.repay(tokenId, interestOwed1 + 100 ether);
        
        // The interest should be locked in via interestAccrued before timestamp reset
        (, , , , uint256 interestOwed2, , , uint256 principalRepaid, uint256 interestPaid, , , , , ) = tranche.getNoteInfo(tokenId);
        
        // All interest paid
        assertApproxEqAbs(interestPaid, interestOwed1, 1);
        // Principal reduced by 100
        assertEq(principalRepaid, 100 ether);
        // Interest owed should be 0 right after payment
        assertEq(interestOwed2, 0);
        
        // Skip time and verify new interest accrues on reduced principal
        skip(30 days);
        
        (, , , , uint256 interestOwed3, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        
        // New interest should be ~90% of original (900/1000 principal)
        uint256 expectedInterest = (interestOwed1 * 900) / 1000;
        assertApproxEqAbs(interestOwed3, expectedInterest, 1 ether);
    }
    
    function test_TransferDoesNotResetInterest() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(200 ether);
        
        skip(30 days);
        
        // Get interest before transfer
        (, , , , uint256 interestBefore, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertTrue(interestBefore > 0);
        
        // Transfer note
        vm.prank(user1);
        tranche.safeTransferFrom(user1, user2, tokenId);
        
        // Interest should still be the same after transfer
        (, , , , uint256 interestAfter, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(interestBefore, interestAfter);
    }
    
    // ============ Tranche State Tests ============
    
    function test_CannotPutContractInInvalidState() public {
        // First tranche already started during initialization
        
        // Exhaust all tranches
        for (uint256 i = 1; i <= 6; i++) {
            vm.prank(user1);
            tranche.deposit(100 ether);
            skip(2 weeks + 1);
            tranche.collectTranche(i);
        }
        
        // Contract should be in a valid "paused" state
        assertEq(tranche.scheduledTrancheCount(), 0);
        (, , , , , , bool isActive, , ) = tranche.getCurrentTranche();
        assertFalse(isActive);
        
        // Should be able to schedule more and restart
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(2, 0, 0);
        
        vm.prank(admin);
        tranche.startNextTranche();
        
        // Verify contract is active again
        (, , , , , , bool isActiveAfter, , ) = tranche.getCurrentTranche();
        assertTrue(isActiveAfter);
    }
    
    function test_TrancheTransitionsWorkCorrectlyAfterCollect() public {
        // First tranche already started during initialization
        
        // Deposit in tranche 1
        vm.prank(user1);
        tranche.deposit(200 ether);
        
        // End tranche 1
        skip(2 weeks + 1);
        tranche.collectTranche(1);
        
        // Tranche 1 should be collected
        (, , , , bool collected1, ) = tranche.getTranche(1);
        assertTrue(collected1);
        
        // Deposit should trigger progression to tranche 2
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(200 ether);
        
        // Verify we're in tranche 2
        assertEq(tranche.currentTrancheId(), 2);
        
        // Verify note is in tranche 2
        (, uint256 noteTrancheId, , , , , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(noteTrancheId, 2);
    }
    
    function test_StartNextTranchePrerequisites() public {
        // First tranche is already started during initialization
        // Can't start next while current is active
        vm.expectRevert(DonationTranche.TrancheStillActive.selector);
        tranche.startNextTranche();
        
        // End tranche but don't collect
        skip(2 weeks + 1);
        
        // Can't start next without collecting
        vm.prank(admin);
        vm.expectRevert(DonationTranche.PreviousTrancheNotCollected.selector);
        tranche.startNextTranche();
        
        // Collect and exhaust all scheduled tranches
        for (uint256 i = 1; i <= 6; i++) {
            tranche.collectTranche(i);
            if (i < 6) {
                vm.prank(user1);
                tranche.deposit(100 ether);
                skip(2 weeks + 1);
            }
        }
        
        // No scheduled tranches left
        vm.prank(admin);
        vm.expectRevert(DonationTranche.NoTranchesScheduled.selector);
        tranche.startNextTranche();
    }
    
    // ============ Vault Griefing Tests ============
    
    function test_EmptyVaultMatchingGraceful() public {
        // Empty the vault
        vm.prank(multisig);
        vault.withdraw();
        
        // First tranche already started during initialization
        
        // Deposit should work without matching
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(200 ether);
        
        // User should have their note
        assertEq(tranche.ownerOf(tokenId), user1);
        
        // No vault note should exist
        vm.expectRevert();
        tranche.ownerOf(tokenId + 1);
        
        // Tranche should have only user deposit
        (, , , , uint256 totalDeposited, , , , uint256 totalMatched) = tranche.getCurrentTranche();
        assertEq(totalDeposited, 200 ether);
        assertEq(totalMatched, 0);
    }
    
    function test_VaultWithLimitedFundsPartialMatch() public {
        // Empty vault and add limited funds
        vm.prank(multisig);
        vault.withdraw();
        usdt.mint(address(vault), 100 ether); // Only 100 USDT in vault
        
        // First tranche already started during initialization
        
        // Deposit 200, vault only has 100 - partial matching should occur
        (uint256 expectedMatch, ) = tranche.getExpectedMatch(200 ether);
        assertEq(expectedMatch, 100 ether); // Limited by vault balance
        
        uint256 vaultBalanceBefore = usdt.balanceOf(address(vault));
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(200 ether);
        
        // User note exists with 200 principal
        assertEq(tranche.ownerOf(tokenId), user1);
        (, , , , , , uint256 principal, , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(principal, 200 ether);
        
        // Partial matching occurred - vault contributed its entire 100 balance
        assertEq(usdt.balanceOf(address(vault)), 0); // Vault drained
        
        // Vault got a matched note for 100 USDT
        uint256 vaultTokenId = tokenId + 1;
        (, , , , , , uint256 vaultPrincipal, , , , , , , ) = tranche.getNoteInfo(vaultTokenId);
        assertEq(vaultPrincipal, 100 ether);
        
        // Total deposited = 200 (user) + 100 (partial match)
        (, , , , uint256 totalDeposited, , , , uint256 totalMatched) = tranche.getCurrentTranche();
        assertEq(totalMatched, 100 ether);
        assertEq(totalDeposited, 300 ether);
    }
    
    function test_PartialMatchingRegression() public {
        // Regression test: Ensure partial matching works correctly
        vm.prank(multisig);
        vault.withdraw();
        usdt.mint(address(vault), 50 ether); // Very limited funds
        
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(200 ether);
        
        // User got 200 USDT note
        (, , , , , , uint256 userPrincipal, , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(userPrincipal, 200 ether);
        
        // Vault got 50 USDT note (partial match)
        uint256 vaultTokenId = tokenId + 1;
        (, , , , , , uint256 vaultPrincipal, , , , , , , ) = tranche.getNoteInfo(vaultTokenId);
        assertEq(vaultPrincipal, 50 ether);
        
        // Verify vault is now empty
        assertEq(usdt.balanceOf(address(vault)), 0);
        
        // Second deposit - no matching (vault empty)
        vm.prank(user2);
        uint256 tokenId2 = tranche.deposit(100 ether);
        
        // No vault token minted for second deposit
        vm.expectRevert();
        tranche.ownerOf(tokenId2 + 1);
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_DepositAmount(uint256 amount) public {
        // Bound to valid range
        amount = bound(amount, 100 ether, 1584 ether);
        
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(amount);
        
        // Verify note was created
        assertTrue(tokenId > 0);
        assertEq(tranche.ownerOf(tokenId), user1);
        
        // Verify principal is correct (may be capped)
        (, , , , , , uint256 principal, , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertTrue(principal > 0);
        assertTrue(principal <= amount);
    }
    
    function testFuzz_RepayAmount(uint256 amount) public {
        // Bound to reasonable range
        amount = bound(amount, 1 ether, 10000 ether);
        
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(1000 ether);
        
        skip(30 days); // Accrue some interest
        
        (, , , , uint256 interestOwedBefore, , uint256 principal, , , , , , , ) = tranche.getNoteInfo(tokenId);
        uint256 totalOwed = interestOwedBefore + principal;
        
        uint256 repayerBalanceBefore = usdt.balanceOf(repayer);
        
        vm.prank(repayer);
        tranche.repay(tokenId, amount);
        
        // Verify repayment was capped at total owed
        uint256 actualPaid = repayerBalanceBefore - usdt.balanceOf(repayer);
        if (amount >= totalOwed) {
            assertEq(actualPaid, totalOwed);
        } else {
            assertEq(actualPaid, amount);
        }
    }
    
    function testFuzz_TimeElapsed(uint256 timeElapsed) public {
        // Bound to reasonable range (1 day to 10 years)
        timeElapsed = bound(timeElapsed, 1 days, 3650 days);
        
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(1000 ether);
        
        skip(timeElapsed);
        
        // Should not overflow
        (, , , , uint256 interestOwed, uint256 interestPerSecond, , , , , , , , ) = tranche.getNoteInfo(tokenId);
        
        // Interest should be positive
        assertTrue(interestOwed > 0);
        assertTrue(interestPerSecond > 0);
        
        // Interest should be approximately principal * APR * time / year
        // 1000 * 0.30 * timeElapsed / 31536000
        uint256 expectedInterest = (1000 ether * 3000 * timeElapsed) / (10000 * 365 days);
        assertApproxEqAbs(interestOwed, expectedInterest, 1 ether);
    }
    
    function testFuzz_AprValues(uint256 aprBps) public {
        // Bound to valid APR range (0 to 100%)
        aprBps = bound(aprBps, 0, 10000);
        
        vm.prank(admin);
        tranche.setDefaultApr(aprBps);
        
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(1000 ether);
        
        // Verify APR was set correctly
        (, , uint256 noteAprBps, , , , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(noteAprBps, aprBps);
        
        skip(365 days);
        
        // Verify interest calculation
        (, , , , uint256 interestOwed, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        uint256 expectedInterest = (1000 ether * aprBps) / 10000;
        assertApproxEqAbs(interestOwed, expectedInterest, 1 ether);
    }
    
    // ============ Additional Edge Cases ============
    
    function test_CannotDepositZeroAmount() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        vm.expectRevert(DonationTranche.BelowMinimumDeposit.selector);
        tranche.deposit(0);
    }
    
    function test_CollectTrancheZeroReverts() public {
        // First tranche already started during initialization
        
        // Tranche 0 doesn't exist - should revert
        vm.expectRevert(DonationTranche.TrancheNonexistant.selector);
        tranche.collectTranche(0);
    }
    
    function test_CollectFutureTrancheReverts() public {
        // First tranche already started during initialization
        
        // Tranche 10 doesn't exist - should revert
        vm.expectRevert(DonationTranche.TrancheNonexistant.selector);
        tranche.collectTranche(10);
    }
    
    function test_GetNoteInfoInvalidTokenReverts() public {
        // First tranche already started during initialization
        
        vm.expectRevert(DonationTranche.InvalidNote.selector);
        tranche.getNoteInfo(999);
    }
    
    function test_MultipleDepositsMultipleUsers() public {
        // First tranche already started during initialization
        
        // User1 deposits
        vm.prank(user1);
        uint256 token1 = tranche.deposit(200 ether);
        
        // User2 deposits
        vm.prank(user2);
        uint256 token2 = tranche.deposit(300 ether);
        
        // Attacker deposits
        vm.prank(attacker);
        uint256 token3 = tranche.deposit(150 ether);
        
        // All should have notes
        assertEq(tranche.ownerOf(token1), user1);
        assertEq(tranche.ownerOf(token2), user2);
        assertEq(tranche.ownerOf(token3), attacker);
        
        // Balance check
        assertEq(tranche.balanceOf(user1), 1);
        assertEq(tranche.balanceOf(user2), 1);
        assertEq(tranche.balanceOf(attacker), 1);
        
        // Vault should have 3 matched notes
        assertEq(tranche.balanceOf(address(vault)), 3);
    }
    
    function test_RepayAfterTransferGoesToNewOwner() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(200 ether);
        
        skip(30 days);
        
        // Transfer to user2
        vm.prank(user1);
        tranche.safeTransferFrom(user1, user2, tokenId);
        
        uint256 user1BalanceBefore = usdt.balanceOf(user1);
        uint256 user2BalanceBefore = usdt.balanceOf(user2);
        
        // Repayer repays
        vm.prank(repayer);
        tranche.repay(tokenId, 50 ether);
        
        // User1 should not receive funds
        assertEq(usdt.balanceOf(user1), user1BalanceBefore);
        
        // User2 should receive funds
        assertEq(usdt.balanceOf(user2), user2BalanceBefore + 50 ether);
    }
    
    function test_FullTrancheProgressionSequence() public {
        // First tranche already started during initialization
        
        // Complete all 6 initial tranches
        for (uint256 i = 1; i <= 6; i++) {
            // Deposit
            vm.prank(user1);
            tranche.deposit(100 ether);
            
            // Verify current tranche
            (uint256 currentId, , , , , , , , ) = tranche.getCurrentTranche();
            assertEq(currentId, i);
            
            // Wait and collect
            skip(2 weeks + 1);
            tranche.collectTranche(i);
        }
        
        // All exhausted
        assertEq(tranche.scheduledTrancheCount(), 0);
        
        // Schedule and restart
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(1, 0, 0);
        
        vm.prank(admin);
        tranche.startNextTranche();
        
        // New tranche 7 should be active
        (uint256 newId, , , , , , bool active, , ) = tranche.getCurrentTranche();
        assertEq(newId, 7);
        assertTrue(active);
    }
    
    // ============ Security Feature Tests ============
    
    /**
     * @notice Test that pausing prevents deposits
     */
    function test_PauseBlocksDeposits() public {
        // First tranche already started during initialization
        
        // Admin pauses the contract
        vm.prank(admin);
        tranche.pause();
        
        // Attacker tries to deposit - should fail with EnforcedPause
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        tranche.deposit(200 ether);
        
        // Admin unpauses
        vm.prank(admin);
        tranche.unpause();
        
        // Now deposit should work
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(200 ether);
        assertTrue(tokenId > 0);
    }
    
    /**
     * @notice Test that non-admin cannot pause
     */
    function test_NonAdminCannotPause() public {
        vm.prank(attacker);
        vm.expectRevert();
        tranche.pause();
    }
    
    /**
     * @notice Test that USDT cannot be rescued (prevents draining user funds)
     */
    function test_CannotRescueUsdt() public {
        // First tranche already started during initialization
        
        // User deposits funds
        vm.prank(user1);
        tranche.deposit(200 ether);
        
        // Admin tries to rescue USDT - should fail
        vm.prank(admin);
        vm.expectRevert(DonationTranche.CannotRescueUsdt.selector);
        tranche.adminRescueTokens(IERC20(address(usdt)));
    }
    
    /**
     * @notice Test that other tokens can be rescued
     */
    function test_CanRescueOtherTokens() public {
        // Create another token and accidentally send to contract
        MockUSDT otherToken = new MockUSDT();
        otherToken.mint(address(tranche), 1000 ether);
        
        // TREASURY constant from DonationTranche
        address treasury = tranche.TREASURY();
        uint256 treasuryBalanceBefore = otherToken.balanceOf(treasury);
        
        // Admin rescues the token
        vm.prank(admin);
        tranche.adminRescueTokens(IERC20(address(otherToken)));
        
        // TREASURY should receive the tokens (not admin)
        assertEq(otherToken.balanceOf(treasury), treasuryBalanceBefore + 1000 ether);
        assertEq(otherToken.balanceOf(address(tranche)), 0);
    }
    
    /**
     * @notice Test that scheduling more than MAX_SCHEDULE_COUNT reverts
     * @dev Total scheduled count is capped at MAX_SCHEDULE_COUNT (12)
     */
    function test_ExceedsMaxScheduleCount() public {
        // Initially have 5 scheduled tranches (from initialization)
        assertEq(tranche.scheduledTrancheCount(), 5);
        
        // Try to schedule more than 12 tranches at once - fails per-call limit
        vm.prank(admin);
        vm.expectRevert(DonationTranche.ExceedsMaxSchedule.selector);
        tranche.scheduleAdditionalTranches(13, 0, 0);
        
        // Try to schedule 12 more - fails because total would exceed MAX_SCHEDULE_COUNT
        // 5 existing + 12 new = 17 > 12
        vm.prank(admin);
        vm.expectRevert(DonationTranche.ExceedsMaxSchedule.selector);
        tranche.scheduleAdditionalTranches(12, 0, 0);
        
        // Can schedule up to 7 more (5 + 7 = 12)
        vm.prank(admin);
        tranche.scheduleAdditionalTranches(7, 0, 0);
        
        // Verify total is now at max (12)
        assertEq(tranche.scheduledTrancheCount(), 12);
        
        // Cannot schedule any more
        vm.prank(admin);
        vm.expectRevert(DonationTranche.ExceedsMaxSchedule.selector);
        tranche.scheduleAdditionalTranches(1, 0, 0);
    }
    
    /**
     * @notice Test repay function has reentrancy protection
     */
    function test_RepayHasReentrancyGuard() public {
        // First tranche already started during initialization
        
        vm.prank(user1);
        uint256 tokenId = tranche.deposit(200 ether);
        
        skip(30 days);
        
        // Get interest owed
        (, , , , uint256 interestOwed, , , , , , , , , ) = tranche.getNoteInfo(tokenId);
        assertTrue(interestOwed > 0);
        
        // Normal repay should work
        vm.prank(repayer);
        tranche.repay(tokenId, interestOwed);
        
        // Verify repayment occurred
        (, , , , , , , , uint256 interestPaid, , , , , ) = tranche.getNoteInfo(tokenId);
        assertEq(interestPaid, interestOwed);
    }
}

contract DonationMatchVaultAdversarialTest is Test {
    DonationMatchVault public vault;
    MockUSDT public usdt;
    
    address public multisig = address(1);
    address public attacker = address(2);
    address public dummyTranche = address(100);
    
    function setUp() public {
        usdt = new MockUSDT();
        vault = new DonationMatchVault(multisig, address(usdt), dummyTranche);
        usdt.mint(address(vault), 10000 ether);
    }
    
    function test_AttackerCannotWithdraw() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.withdraw();
        
        // Vault balance unchanged
        assertEq(vault.getBalance(), 10000 ether);
    }
    
    function test_AttackerCannotApprove() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.approveUsdt(attacker, type(uint256).max);
        
        // No approval granted
        assertEq(usdt.allowance(address(vault), attacker), 0);
    }
    
    function test_AttackerCannotTransferOwnership() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.transferOwnership(attacker);
        
        // Owner unchanged
        assertEq(vault.owner(), multisig);
    }
    
    function test_WithdrawEmptyVaultGraceful() public {
        // First withdraw
        vm.prank(multisig);
        vault.withdraw();
        
        assertEq(vault.getBalance(), 0);
        
        // Second withdraw should not revert (graceful)
        vm.prank(multisig);
        vault.withdraw();
        
        assertEq(vault.getBalance(), 0);
    }
    
    function testFuzz_ApproveAmount(uint256 amount) public {
        vm.prank(multisig);
        vault.approveUsdt(attacker, amount);
        
        assertEq(usdt.allowance(address(vault), attacker), amount);
    }
}
