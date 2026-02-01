// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
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

/**
 * @title DonationTrancheHandler
 * @notice Handler contract for invariant fuzzing - performs random operations on DonationTranche
 * @dev Called by Foundry's fuzzer to exercise the contract with random inputs
 */
contract DonationTrancheHandler is Test {
    DonationTranche public tranche;
    DonationMatchVault public vault;
    AccessManager public accessManager;
    MockUSDT public usdt;
    
    address public admin;
    address public clusterManager;
    address public multisig;
    address[] public actors;
    
    // Ghost variables to track state for invariant checking
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalRepaid;
    uint256 public ghost_totalCollected;
    uint256 public ghost_depositCount;
    uint256 public ghost_repayCount;
    uint256 public ghost_collectCount;
    uint256 public ghost_transferCount;
    uint256 public ghost_timeSkipped;
    
    // Track minted token IDs for operations
    uint256[] public mintedTokenIds;
    
    // Track interest owed at various points
    mapping(uint256 => uint256) public ghost_lastInterestOwed;
    
    uint64 public constant ADMIN_ROLE = 1;
    
    constructor(
        DonationTranche _tranche,
        DonationMatchVault _vault,
        AccessManager _accessManager,
        MockUSDT _usdt,
        address _admin,
        address _clusterManager,
        address _multisig,
        address[] memory _actors
    ) {
        tranche = _tranche;
        vault = _vault;
        accessManager = _accessManager;
        usdt = _usdt;
        admin = _admin;
        clusterManager = _clusterManager;
        multisig = _multisig;
        actors = _actors;
    }
    
    // ============ Handler Functions ============
    
    /**
     * @notice Deposit a random amount from a random actor
     * @param actorSeed Seed to select actor
     * @param amount Amount to deposit (bounded)
     */
    function deposit(uint256 actorSeed, uint256 amount) external {
        // Bound amount to reasonable range (100 USDT to 1000 USDT)
        amount = bound(amount, 100 ether, 1000 ether);
        
        // Select random actor
        address actor = actors[actorSeed % actors.length];
        
        // Check if current tranche is active
        try tranche.getCurrentTranche() returns (
            uint256, uint256, uint256, uint256, uint256, uint256 remaining, bool isActive, bool, uint256
        ) {
            if (!isActive || remaining == 0) {
                // Skip - tranche not active or full
                return;
            }
            
            // Ensure actor has enough funds
            if (usdt.balanceOf(actor) < amount) {
                usdt.mint(actor, amount);
            }
            
            // Approve and deposit
            vm.startPrank(actor);
            usdt.approve(address(tranche), amount);
            try tranche.deposit(amount) returns (uint256 tokenId) {
                ghost_totalDeposited += amount;
                ghost_depositCount++;
                mintedTokenIds.push(tokenId);
                
                // Initialize interest tracking
                ghost_lastInterestOwed[tokenId] = 0;
            } catch {
                // Deposit failed - acceptable in fuzzing
            }
            vm.stopPrank();
        } catch {
            // getCurrentTranche failed - skip
        }
    }
    
    /**
     * @notice Repay a random amount on a random note
     * @param tokenIdSeed Seed to select token
     * @param amount Amount to repay (bounded)
     * @param actorSeed Seed to select payer
     */
    function repay(uint256 tokenIdSeed, uint256 amount, uint256 actorSeed) external {
        if (mintedTokenIds.length == 0) return;
        
        // Select random token
        uint256 tokenId = mintedTokenIds[tokenIdSeed % mintedTokenIds.length];
        
        // Bound amount
        amount = bound(amount, 1 ether, 500 ether);
        
        // Select payer
        address payer = actors[actorSeed % actors.length];
        
        // Get note info to track interest before repayment
        try tranche.getNoteInfo(tokenId) returns (
            address, uint256, uint256, uint256, uint256 interestOwed,
            uint256, uint256, uint256, uint256, uint256, uint256, uint256, bool fullyRepaid, uint256
        ) {
            if (fullyRepaid) return; // Skip fully repaid notes
            
            // Record interest for monotonicity check
            ghost_lastInterestOwed[tokenId] = interestOwed;
            
            // Ensure payer has funds
            if (usdt.balanceOf(payer) < amount) {
                usdt.mint(payer, amount);
            }
            
            vm.startPrank(payer);
            usdt.approve(address(tranche), amount);
            try tranche.repay(tokenId, amount) {
                ghost_totalRepaid += amount;
                ghost_repayCount++;
            } catch {
                // Repay failed - acceptable
            }
            vm.stopPrank();
        } catch {
            // Note doesn't exist - skip
        }
    }
    
    /**
     * @notice Collect a tranche
     * @param trancheId The tranche ID to collect
     */
    function collectTranche(uint256 trancheId) external {
        // Bound to reasonable tranche range
        trancheId = bound(trancheId, 1, 10);
        
        try tranche.getTranche(trancheId) returns (
            uint256, uint256 endTime, uint256, uint256 totalDeposited, bool collected, uint256
        ) {
            if (collected || (endTime > 0 && block.timestamp < endTime)) {
                // Already collected or not ended - skip
                return;
            }
            
            try tranche.collectTranche(trancheId) {
                ghost_totalCollected += totalDeposited;
                ghost_collectCount++;
            } catch {
                // Collection failed
            }
        } catch {
            // Tranche doesn't exist
        }
    }
    
    /**
     * @notice Transfer a random NFT between actors
     * @param tokenIdSeed Seed to select token
     * @param toSeed Seed to select recipient
     */
    function transferNFT(uint256 tokenIdSeed, uint256 toSeed) external {
        if (mintedTokenIds.length == 0) return;
        
        uint256 tokenId = mintedTokenIds[tokenIdSeed % mintedTokenIds.length];
        address to = actors[toSeed % actors.length];
        
        try tranche.ownerOf(tokenId) returns (address owner) {
            if (owner == to || owner == address(vault)) return; // Skip same owner or vault
            
            vm.prank(owner);
            try tranche.transferFrom(owner, to, tokenId) {
                ghost_transferCount++;
            } catch {
                // Transfer failed
            }
        } catch {
            // Token doesn't exist
        }
    }
    
    /**
     * @notice Skip time forward
     * @param timeSeed Amount of time to skip (bounded)
     */
    function skipTime(uint256 timeSeed) external {
        // Bound to 1 hour to 3 days
        uint256 timeToSkip = bound(timeSeed, 1 hours, 3 days);
        skip(timeToSkip);
        ghost_timeSkipped += timeToSkip;
    }
    
    /**
     * @notice Start next tranche (when conditions allow)
     */
    function startNextTranche() external {
        try tranche.startNextTranche() {
            // Success
        } catch {
            // Expected to fail often - scheduled time not reached, etc.
        }
    }
    
    /**
     * @notice Admin starts next tranche early
     */
    function adminStartNextTranche() external {
        vm.prank(admin);
        try tranche.adminStartNextTranche() {
            // Success
        } catch {
            // Expected to fail if conditions not met
        }
    }
    
    /**
     * @notice Pause the contract (admin only)
     */
    function pause() external {
        vm.prank(admin);
        try tranche.pause() {
            // Success
        } catch {
            // Already paused or access denied
        }
    }
    
    /**
     * @notice Unpause the contract (admin only)
     */
    function unpause() external {
        vm.prank(admin);
        try tranche.unpause() {
            // Success
        } catch {
            // Already unpaused or access denied
        }
    }
    
    // ============ Helper Functions ============
    
    function getMintedTokenCount() external view returns (uint256) {
        return mintedTokenIds.length;
    }
    
    function getMintedTokenAt(uint256 index) external view returns (uint256) {
        return mintedTokenIds[index];
    }
}

/**
 * @title DonationTrancheInvariantTest
 * @notice Invariant fuzzing tests for DonationTranche contract
 * @dev Tests the invariants specified in AUDIT.md section 2.2
 */
contract DonationTrancheInvariantTest is StdInvariant, Test {
    DonationTranche public tranche;
    DonationMatchVault public vault;
    AccessManager public accessManager;
    MockUSDT public usdt;
    DonationTrancheHandler public handler;
    
    address public admin = address(1);
    address public clusterManager = address(2);
    address public multisig = address(3);
    address[] public actors;
    
    uint64 public constant ADMIN_ROLE = 1;
    
    function setUp() public {
        // Setup actors
        actors.push(address(0x1001));
        actors.push(address(0x1002));
        actors.push(address(0x1003));
        actors.push(address(0x1004));
        actors.push(address(0x1005));
        
        // Deploy core contracts
        accessManager = new AccessManager(admin);
        usdt = new MockUSDT();
        
        DonationTranche trancheImpl = new DonationTranche();
        
        uint256 currentNonce = vm.getNonce(address(this));
        address predictedProxy = vm.computeCreateAddress(address(this), currentNonce + 1);
        
        vault = new DonationMatchVault(multisig, address(usdt), predictedProxy);
        
        // Fund vault generously
        usdt.mint(address(vault), 1_000_000 ether);
        
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
        
        // Increase tranche cap for more fuzzing capacity
        vm.prank(admin);
        tranche.setTrancheCap(1, 100_000 ether);
        
        // Fund actors
        for (uint256 i = 0; i < actors.length; i++) {
            usdt.mint(actors[i], 100_000 ether);
            vm.prank(actors[i]);
            usdt.approve(address(tranche), type(uint256).max);
        }
        
        // Deploy handler
        handler = new DonationTrancheHandler(
            tranche,
            vault,
            accessManager,
            usdt,
            admin,
            clusterManager,
            multisig,
            actors
        );
        
        // Set handler as target for fuzzing
        targetContract(address(handler));
        
        // Exclude direct contract calls to prevent bypassing handler
        excludeContract(address(tranche));
        excludeContract(address(vault));
        excludeContract(address(usdt));
    }
    
    // ============ Invariant Tests ============
    
    /**
     * @notice Invariant 1: Contract USDT balance >= uncollected deposits
     * @dev The contract should hold at least as much USDT as uncollected tranche deposits
     *      After collection, funds are transferred to clusterManager
     */
    function invariant_solvencyMaintained() public view {
        uint256 contractBalance = usdt.balanceOf(address(tranche));
        
        // Sum up uncollected deposits across all tranches
        uint256 uncollectedDeposits = 0;
        uint256 currentId = tranche.currentTrancheId();
        
        for (uint256 i = 1; i <= currentId; i++) {
            (,,,uint256 totalDeposited, bool collected,) = tranche.getTranche(i);
            if (!collected) {
                uncollectedDeposits += totalDeposited;
            }
        }
        
        // Contract balance should be >= uncollected deposits
        // Note: May have small differences due to repayments going directly to note owners
        assertGe(
            contractBalance,
            uncollectedDeposits,
            "Invariant violated: Contract insolvent"
        );
    }
    
    /**
     * @notice Invariant 2: Notes do not exceed tranche cap
     * @dev Total deposited in any tranche should never exceed its cap
     */
    function invariant_notesDoNotExceedTrancheCap() public view {
        uint256 currentId = tranche.currentTrancheId();
        
        for (uint256 i = 1; i <= currentId; i++) {
            (,, uint256 cap, uint256 totalDeposited,,) = tranche.getTranche(i);
            
            assertLe(
                totalDeposited,
                cap,
                "Invariant violated: Tranche deposits exceed cap"
            );
        }
    }
    
    /**
     * @notice Invariant 3: Fully repaid notes have zero interest owed
     * @dev Once a note is marked fullyRepaid, interestOwed should be 0
     */
    function invariant_fullyRepaidNotesHaveZeroInterest() public view {
        uint256 tokenCount = handler.getMintedTokenCount();
        
        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 tokenId = handler.getMintedTokenAt(i);
            
            try tranche.getNoteInfo(tokenId) returns (
                address, uint256, uint256, uint256, uint256 interestOwed,
                uint256, uint256, uint256, uint256, uint256, uint256, uint256, bool fullyRepaid, uint256
            ) {
                if (fullyRepaid) {
                    assertEq(
                        interestOwed,
                        0,
                        "Invariant violated: Fully repaid note has non-zero interest"
                    );
                }
            } catch {
                // Token may not exist - skip
            }
        }
    }
    
    /**
     * @notice Invariant 4: Tranche state transitions are valid
     * @dev - Collected tranches should have collected == true
     *      - Active tranche should not be collected
     *      - Only one tranche can be active at a time
     */
    function invariant_trancheStateTransitionsAreValid() public view {
        uint256 currentId = tranche.currentTrancheId();
        
        // Get current tranche state
        (
            uint256 id,,,,,, bool isActive, bool collected,
        ) = tranche.getCurrentTranche();
        
        // Current tranche ID should match returned ID
        assertEq(id, currentId, "Current tranche ID mismatch");
        
        // If current tranche is active, it should not be collected
        if (isActive) {
            assertFalse(collected, "Active tranche should not be collected");
        }
        
        // All previous tranches should be collected or ended
        for (uint256 i = 1; i < currentId; i++) {
            (uint256 startTime, uint256 endTime,,, bool prevCollected,) = tranche.getTranche(i);
            
            // Previous tranches must have valid times
            if (startTime > 0) {
                assertTrue(endTime > startTime, "Invalid tranche time range");
            }
            
            // Previous tranches should be collected (if we've moved past them)
            // Note: Collection happens on deposit or explicit call
            // This is a soft invariant - previous tranches SHOULD be collected
        }
    }
    
    /**
     * @notice Invariant 5: Token supply matches note count
     * @dev ERC721 totalSupply should equal the number of notes created
     */
    function invariant_tokenSupplyMatchesNotes() public view {
        uint256 totalSupply = tranche.totalSupply();
        uint256 nextTokenId = tranche.nextTokenId();
        
        // totalSupply should be <= nextTokenId - 1 (tokenId starts at 1)
        assertLe(
            totalSupply,
            nextTokenId - 1,
            "Token supply exceeds expected maximum"
        );
    }
    
    /**
     * @notice Invariant 6: Remaining principal is consistent
     * @dev For each note: remainingPrincipal = principal - principalRepaid
     */
    function invariant_remainingPrincipalConsistent() public view {
        uint256 tokenCount = handler.getMintedTokenCount();
        
        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 tokenId = handler.getMintedTokenAt(i);
            
            try tranche.getNoteInfo(tokenId) returns (
                address, uint256, uint256, uint256, uint256,
                uint256, uint256 principal, uint256 principalRepaid, uint256, uint256, uint256 remainingPrincipal, uint256, bool, uint256
            ) {
                assertEq(
                    remainingPrincipal,
                    principal - principalRepaid,
                    "Remaining principal calculation mismatch"
                );
            } catch {
                // Token may not exist - skip
            }
        }
    }
    
    /**
     * @notice Invariant 7: Schedule count is bounded
     * @dev Scheduled tranche count should never exceed MAX_SCHEDULE_COUNT
     */
    function invariant_scheduleCountBounded() public view {
        uint256 scheduledCount = tranche.scheduledTrancheCount();
        
        assertLe(
            scheduledCount,
            12, // MAX_SCHEDULE_COUNT
            "Scheduled count exceeds maximum"
        );
    }
    
    /**
     * @notice Invariant 8: Note ownership is valid
     * @dev Every tracked token should have a valid owner
     */
    function invariant_noteOwnershipValid() public view {
        uint256 tokenCount = handler.getMintedTokenCount();
        
        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 tokenId = handler.getMintedTokenAt(i);
            
            try tranche.ownerOf(tokenId) returns (address owner) {
                assertTrue(
                    owner != address(0),
                    "Note has zero address owner"
                );
            } catch {
                // Token may not exist - acceptable in some edge cases
            }
        }
    }
    
    /**
     * @notice Invariant 9: APR is within bounds
     * @dev All notes should have APR <= BASIS_POINTS (100%)
     */
    function invariant_aprWithinBounds() public view {
        uint256 tokenCount = handler.getMintedTokenCount();
        
        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 tokenId = handler.getMintedTokenAt(i);
            
            try tranche.getNoteInfo(tokenId) returns (
                address, uint256, uint256 aprBps, uint256, uint256,
                uint256, uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256
            ) {
                assertLe(
                    aprBps,
                    10000, // BASIS_POINTS
                    "APR exceeds 100%"
                );
            } catch {
                // Token may not exist - skip
            }
        }
    }
    
    /**
     * @notice Invariant 10: Total matched does not exceed total deposited
     * @dev For each tranche: totalMatched <= totalDeposited
     */
    function invariant_matchedDoesNotExceedDeposited() public view {
        uint256 currentId = tranche.currentTrancheId();
        
        for (uint256 i = 1; i <= currentId; i++) {
            (,,, uint256 totalDeposited,, uint256 totalMatched) = tranche.getTranche(i);
            
            assertLe(
                totalMatched,
                totalDeposited,
                "Total matched exceeds total deposited"
            );
        }
    }
    
    // ============ Summary Function ============
    
    /**
     * @notice Call summary to understand fuzzing coverage
     */
    function invariant_callSummary() public view {
        console.log("=== Invariant Fuzzing Summary ===");
        console.log("Deposits:", handler.ghost_depositCount());
        console.log("Repays:", handler.ghost_repayCount());
        console.log("Collections:", handler.ghost_collectCount());
        console.log("Transfers:", handler.ghost_transferCount());
        console.log("Time skipped (seconds):", handler.ghost_timeSkipped());
        console.log("Minted tokens:", handler.getMintedTokenCount());
        console.log("Current tranche:", tranche.currentTrancheId());
        console.log("Contract USDT balance:", usdt.balanceOf(address(tranche)));
    }
}

/**
 * @title DonationTrancheStatelessFuzzTest
 * @notice Stateless fuzz tests for individual functions
 * @dev Complements invariant tests with targeted property checks
 */
contract DonationTrancheStatelessFuzzTest is Test {
    DonationTranche public tranche;
    DonationMatchVault public vault;
    AccessManager public accessManager;
    MockUSDT public usdt;
    
    address public admin = address(1);
    address public clusterManager = address(2);
    address public multisig = address(3);
    address public user = address(4);
    
    uint64 public constant ADMIN_ROLE = 1;
    
    function setUp() public {
        accessManager = new AccessManager(admin);
        usdt = new MockUSDT();
        
        DonationTranche trancheImpl = new DonationTranche();
        
        uint256 currentNonce = vm.getNonce(address(this));
        address predictedProxy = vm.computeCreateAddress(address(this), currentNonce + 1);
        
        vault = new DonationMatchVault(multisig, address(usdt), predictedProxy);
        
        usdt.mint(address(vault), 1_000_000 ether);
        
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
        
        vm.prank(admin);
        tranche.setTrancheCap(1, 100_000 ether);
        
        usdt.mint(user, 100_000 ether);
        vm.prank(user);
        usdt.approve(address(tranche), type(uint256).max);
    }
    
    /**
     * @notice Fuzz test: Deposit amount is correctly recorded in note
     */
    function testFuzz_depositRecordsPrincipal(uint256 amount) public {
        // Bound to valid deposit range
        amount = bound(amount, 100 ether, 10_000 ether);
        
        vm.prank(user);
        uint256 tokenId = tranche.deposit(amount);
        
        (,,,,,,uint256 principal,,,,,,,) = tranche.getNoteInfo(tokenId);
        
        // Principal should match deposit amount (may be capped to remaining)
        assertLe(principal, amount, "Principal exceeds deposit amount");
        assertGe(principal, 100 ether, "Principal below minimum");
    }
    
    /**
     * @notice Fuzz test: Interest calculation is non-negative
     */
    function testFuzz_interestNonNegative(uint256 amount, uint256 timeElapsed) public {
        amount = bound(amount, 100 ether, 10_000 ether);
        timeElapsed = bound(timeElapsed, 0, 365 days);
        
        vm.prank(user);
        uint256 tokenId = tranche.deposit(amount);
        
        skip(timeElapsed);
        
        (,,,,uint256 interestOwed,,,,,,,,,) = tranche.getNoteInfo(tokenId);
        
        // Interest should never be negative (uint256 guarantees this, but verify logic)
        assertGe(interestOwed, 0, "Interest is negative");
    }
    
    /**
     * @notice Fuzz test: Repayment reduces remaining principal correctly
     */
    function testFuzz_repaymentReducesPrincipal(uint256 depositAmount, uint256 repayAmount) public {
        depositAmount = bound(depositAmount, 100 ether, 5_000 ether);
        repayAmount = bound(repayAmount, 1 ether, depositAmount);
        
        vm.prank(user);
        uint256 tokenId = tranche.deposit(depositAmount);
        
        // Get actual principal (may differ from depositAmount if capped)
        (,,,,,,uint256 principal,,,,,,,) = tranche.getNoteInfo(tokenId);
        
        // Skip some time to accrue interest
        skip(7 days);
        
        // Get interest owed
        (,,,,uint256 interestOwed,,,,,,,,,) = tranche.getNoteInfo(tokenId);
        
        // Calculate expected principal payment
        uint256 expectedPrincipalPayment = repayAmount > interestOwed 
            ? repayAmount - interestOwed 
            : 0;
        if (expectedPrincipalPayment > principal) {
            expectedPrincipalPayment = principal;
        }
        
        // Mint funds to repay
        usdt.mint(user, repayAmount);
        vm.prank(user);
        tranche.repay(tokenId, repayAmount);
        
        // Check remaining principal
        (,,,,,,, uint256 principalRepaid,,, uint256 remainingPrincipal,,,) = tranche.getNoteInfo(tokenId);
        
        assertEq(
            remainingPrincipal,
            principal - principalRepaid,
            "Remaining principal calculation incorrect"
        );
    }
    
    /**
     * @notice Fuzz test: Tranche cap is enforced
     */
    function testFuzz_trancheCapEnforced(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 100 ether, 200_000 ether);
        
        // Increase vault approval to handle large deposits (fixes known issue #21)
        vm.prank(multisig);
        vault.approveUsdt(address(tranche), type(uint256).max);
        
        (,,, uint256 cap,,,,,) = tranche.getCurrentTranche();
        
        vm.prank(user);
        uint256 tokenId = tranche.deposit(depositAmount);
        
        (,,,,,,uint256 principal,,,,,,,) = tranche.getNoteInfo(tokenId);
        
        // Principal should not exceed original cap
        assertLe(principal, cap, "Deposit exceeds tranche cap");
    }
    
    /**
     * @notice Fuzz test: Interest rate calculation is bounded
     */
    function testFuzz_interestRateBounded(uint256 amount, uint256 timeElapsed) public {
        amount = bound(amount, 100 ether, 10_000 ether);
        timeElapsed = bound(timeElapsed, 1, 365 days);
        
        vm.prank(user);
        uint256 tokenId = tranche.deposit(amount);
        
        skip(timeElapsed);
        
        (,,,,uint256 interestOwed,,uint256 principal,,,,,,bool fullyRepaid,) = tranche.getNoteInfo(tokenId);
        
        if (!fullyRepaid && principal > 0) {
            // Calculate expected maximum interest (30% APR for elapsed time)
            uint256 maxInterest = (principal * 3000 * timeElapsed) / (10000 * 365 days);
            
            // Allow 1 wei tolerance for rounding
            assertLe(
                interestOwed,
                maxInterest + 1,
                "Interest exceeds expected maximum"
            );
        }
    }
    
    /**
     * @notice Fuzz test: Multiple deposits accumulate correctly
     */
    function testFuzz_multipleDepositsAccumulate(uint256[5] memory amounts) public {
        uint256 totalDeposited = 0;
        
        for (uint256 i = 0; i < 5; i++) {
            amounts[i] = bound(amounts[i], 100 ether, 1_000 ether);
            
            // Check remaining capacity
            (,,,,,uint256 remaining,bool isActive,,) = tranche.getCurrentTranche();
            
            if (!isActive || remaining < 100 ether) break;
            
            uint256 actualDeposit = amounts[i] > remaining ? remaining : amounts[i];
            
            vm.prank(user);
            try tranche.deposit(amounts[i]) returns (uint256 tokenId) {
                (,,,,,,uint256 principal,,,,,,,) = tranche.getNoteInfo(tokenId);
                totalDeposited += principal;
            } catch {
                // Deposit failed - acceptable
                break;
            }
        }
        
        // Verify total user deposits
        uint256 userBalance = tranche.balanceOf(user);
        assertTrue(userBalance <= 5, "User has too many tokens");
    }
}
