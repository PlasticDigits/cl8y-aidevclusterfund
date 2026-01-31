// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {DoubleEndedQueue} from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";

/**
 * @title DonationTranche
 * @notice Manages 2-week fundraising tranches with NFT donation notes
 * @dev Each NFT represents a donation with fixed APR rewards
 */
contract DonationTranche is ERC721Enumerable, AccessManaged {
    using SafeERC20 for IERC20;
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    // ============ Constants ============
    
    uint256 public constant TRANCHE_DURATION = 2 weeks;
    uint256 public constant DEFAULT_TRANCHE_CAP = 1584 ether; // 1584 USDT (18 decimals)
    uint256 public constant MIN_DEPOSIT = 100 ether; // 100 USDT
    uint256 public constant DUST_THRESHOLD = 1 ether; // 1 USDT
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant BASIS_POINTS = 10000;
    
    // ============ Immutables ============
    
    IERC20 public immutable usdt;
    address public immutable clusterManager;
    
    // ============ State Variables ============
    
    address public vault;
    uint256 public defaultAprBps = 3000; // 30% = 3000 basis points
    uint256 public nextTokenId = 1;
    uint256 public currentTrancheId;
    bool public firstTrancheStarted;
    
    /// @dev Queue of scheduled tranche start times (stored as bytes32, cast to uint256)
    DoubleEndedQueue.Bytes32Deque internal _scheduledStartTimes;
    
    // ============ Structs ============
    
    struct Tranche {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        uint256 cap;
        uint256 totalDeposited;
        uint256 totalMatched;
        bool collected;
    }
    
    struct Note {
        uint256 trancheId;
        uint256 principal;
        uint256 aprBps;
        uint256 timestamp;
        uint256 principalRepaid;
        uint256 interestPaid;
        uint256 interestAccrued;  // Interest locked in before last timestamp reset
        bool fullyRepaid;
        uint256 completedTimestamp;
    }
    
    // ============ Mappings ============
    
    mapping(uint256 => Tranche) public tranches;
    mapping(uint256 => Note) public notes;
    
    // ============ Events ============
    
    event TrancheStarted(uint256 indexed trancheId, uint256 startTime, uint256 endTime, uint256 cap);
    event TrancheCollected(uint256 indexed trancheId, uint256 amount);
    event Deposited(uint256 indexed tokenId, address indexed depositor, uint256 amount, uint256 trancheId, bool matched);
    event Repaid(uint256 indexed tokenId, address indexed payer, uint256 interestPaid, uint256 principalPaid);
    event NoteCompleted(uint256 indexed tokenId, uint256 totalPrincipalRepaid, uint256 totalInterestPaid);
    event VaultUpdated(address indexed oldVault, address indexed newVault);
    event DefaultAprUpdated(uint256 oldApr, uint256 newApr);
    event TranchesScheduled(uint256 count, uint256 totalScheduled);
    
    // ============ Errors ============
    
    error TrancheNotActive();
    error TrancheNotEnded();
    error TrancheAlreadyCollected();
    error BelowMinimumDeposit();
    error NoTranchesScheduled();
    error FirstTrancheAlreadyStarted();
    error FirstTrancheNotStarted();
    error TrancheStillActive();
    error PreviousTrancheNotCollected();
    error NoteFullyRepaid();
    error InvalidNote();
    error ZeroAmount();
    error TrancheFull();
    error InvalidStartTime();
    error TrancheNonexistant();
    
    // ============ Constructor ============
    
    constructor(
        address _authority,
        address _usdt,
        address _clusterManager,
        address _vault
    ) ERC721("CL8Y Donation Note", "CL8Y-DN") AccessManaged(_authority) {
        usdt = IERC20(_usdt);
        clusterManager = _clusterManager;
        vault = _vault;
        
        // Initialize 6 placeholder entries (actual times set in startFirstTranche)
        for (uint256 i = 0; i < 6; i++) {
            _scheduledStartTimes.pushBack(bytes32(0));
        }
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Start the first tranche with explicit start time
     * @dev Can only be called once by admin. Also sets up all scheduled tranche times.
     * @param startTimestamp When the first tranche should start (must be >= block.timestamp)
     */
    function startFirstTranche(uint256 startTimestamp) external restricted {
        if(startTimestamp == 0) startTimestamp = block.timestamp;
        if (firstTrancheStarted) revert FirstTrancheAlreadyStarted();
        if (_scheduledStartTimes.empty()) revert NoTranchesScheduled();
        if (startTimestamp < block.timestamp) revert InvalidStartTime();
        
        firstTrancheStarted = true;
        
        // Get the count of scheduled tranches (including first one) and clear placeholders
        uint256 totalScheduled = _scheduledStartTimes.length();
        _scheduledStartTimes.clear();
        
        // Create tranche 1 directly (not using _startNewTrancheAt since queue is empty)
        currentTrancheId = 1;
        Tranche storage tranche = tranches[1];
        tranche.id = 1;
        tranche.startTime = startTimestamp;
        tranche.endTime = startTimestamp + TRANCHE_DURATION;
        tranche.cap = DEFAULT_TRANCHE_CAP;
        
        emit TrancheStarted(1, startTimestamp, tranche.endTime, tranche.cap);
        
        // Schedule remaining tranches (totalScheduled - 1) with 2-week intervals
        uint256 baseTime = startTimestamp + TRANCHE_DURATION;
        for (uint256 i = 0; i < totalScheduled - 1; i++) {
            _scheduledStartTimes.pushBack(bytes32(baseTime + (i * TRANCHE_DURATION)));
        }
    }
    
    /**
     * @notice Start the next tranche after a gap in fundraising
     * @dev Called when all previous tranches expired and were collected, 
     *      and new tranches have been scheduled. Generally not needed as
     *      tranches auto-progress on deposit, but can be used to manually start.
     */
    function startNextTranche() external restricted {
        if (!firstTrancheStarted) revert FirstTrancheNotStarted();
        if (_scheduledStartTimes.empty()) revert NoTranchesScheduled();
        
        // Verify current tranche is ended and collected
        Tranche storage current = tranches[currentTrancheId];
        if (current.endTime > 0 && block.timestamp < current.endTime) revert TrancheStillActive();
        if (current.endTime > 0 && !current.collected) revert PreviousTrancheNotCollected();
        
        // Get the next scheduled start time
        uint256 nextStart = uint256(_scheduledStartTimes.front());
        // If scheduled time is in the future, use current time (admin override)
        if (nextStart > block.timestamp) {
            nextStart = block.timestamp;
        }
        
        _startNewTrancheAt(nextStart);
    }
    
    /**
     * @notice Schedule additional tranches
     * @param count Number of tranches to add
     * @param startOverride Start time for first new tranche (0 = auto-calculate based on existing schedule)
     */
    function scheduleAdditionalTranches(
        uint256 count, 
        uint256 startOverride
    ) external restricted {
        // Calculate base start time for first new tranche
        uint256 baseTime;
        if (startOverride != 0) {
            // Explicit start time provided - must be now or in future
            if (startOverride < block.timestamp) revert InvalidStartTime();
            // If pending tranches, do not allow scheduling new tranches before the last one ends
            if (uint256(_scheduledStartTimes.back()) > startOverride + TRANCHE_DURATION) revert InvalidStartTime();
            baseTime = startOverride;
        } else if (!_scheduledStartTimes.empty()) {
            // Have pending scheduled tranches - continue from last one
            baseTime = uint256(_scheduledStartTimes.back()) + TRANCHE_DURATION;
        } else if (currentTrancheId > 0 && tranches[currentTrancheId].endTime > block.timestamp) {
            // Current tranche still active - schedule after it ends
            baseTime = tranches[currentTrancheId].endTime;
        } else if (currentTrancheId > 0) {
            // All tranches ended - start from now
            baseTime = block.timestamp;
        } else {
            // No tranches exist yet - start from now
            baseTime = block.timestamp;
        }
        
        for (uint256 i = 0; i < count; i++) {
            _scheduledStartTimes.pushBack(bytes32(baseTime + (i * TRANCHE_DURATION)));
        }
        emit TranchesScheduled(count, _scheduledStartTimes.length());
    }
    
    /**
     * @notice Update the vault address
     * @param newVault New vault address
     */
    function setVault(address newVault) external restricted {
        address oldVault = vault;
        vault = newVault;
        emit VaultUpdated(oldVault, newVault);
    }
    
    /**
     * @notice Update default APR for new notes
     * @param newAprBps New APR in basis points
     */
    function setDefaultApr(uint256 newAprBps) external restricted {
        uint256 oldApr = defaultAprBps;
        defaultAprBps = newAprBps;
        emit DefaultAprUpdated(oldApr, newAprBps);
    }

    /** @notice Allows the administrator to rescue any ERC20 tokens accidentally sent to the contract
    * @dev Includes USDT, in case an unexpected issue prevents the vault from withdrawing funds.
    * @param _token The ERC20 token contract to rescue
    */
    function adminRescueTokens(IERC20 _token) external restricted {
        _token.transfer(msg.sender, _token.balanceOf(address(this)));
    }
    
    // ============ Public Functions ============
    
    /**
     * @notice Deposit USDT into the current tranche and receive a donation note NFT
     * @dev If amount exceeds remaining capacity, only the remaining capacity is deposited.
     *      Matching is skipped if tranche becomes full, or limited to remaining capacity.
     *      Auto-progresses to next tranche if current has ended and next is scheduled.
     * @param amount Amount of USDT to deposit (may be reduced to fit remaining capacity)
     * @return tokenId The ID of the minted donation note
     */
    function deposit(uint256 amount) external returns (uint256 tokenId) {
        // Auto-progress to next tranche if needed (triggers lazy collection)
        _ensureCurrentTranche();
        
        Tranche storage tranche = tranches[currentTrancheId];
        
        // Validate tranche timing is active (ignore capacity check - we handle it below)
        if (tranche.startTime == 0 || 
            block.timestamp < tranche.startTime || 
            block.timestamp >= tranche.endTime) {
            revert TrancheNotActive();
        }
        
        uint256 remaining = tranche.cap - tranche.totalDeposited;
        
        // If tranche has zero remaining, revert with TrancheFull
        if (remaining == 0) revert TrancheFull();
        
        // Adjust amount if it exceeds remaining capacity
        uint256 actualAmount = amount > remaining ? remaining : amount;
        
        // Calculate effective minimum deposit
        // When remaining < MIN_DEPOSIT * 2, allow deposits of (remaining / 2) + 0.001 ether
        // This allows the tranche to be fully filled with matching
        uint256 effectiveMin = _getEffectiveMinDeposit(remaining);
        if (actualAmount < effectiveMin) revert BelowMinimumDeposit();
        
        // Transfer USDT from depositor (only actual amount)
        usdt.safeTransferFrom(msg.sender, address(this), actualAmount);
        tranche.totalDeposited += actualAmount;
        
        // Mint note to depositor with actual amount
        tokenId = _mintNote(msg.sender, actualAmount);
        
        // Calculate remaining capacity after user deposit
        uint256 remainingAfterDeposit = tranche.cap - tranche.totalDeposited;
        
        // Attempt matching from vault (respecting capacity limits)
        bool matched = false;
        if (remainingAfterDeposit > 0) {
            // Match the lesser of: actualAmount or remainingAfterDeposit
            uint256 matchAmount = actualAmount > remainingAfterDeposit ? remainingAfterDeposit : actualAmount;
            matched = _attemptMatch(matchAmount);
        }
        // If remainingAfterDeposit == 0, skip matching entirely
        
        emit Deposited(tokenId, msg.sender, actualAmount, currentTrancheId, matched);
    }
    
    /**
     * @notice Repay a donation note (interest first, then principal)
     * @param tokenId The note to repay
     * @param amount Amount of USDT to pay
     */
    function repay(uint256 tokenId, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (!_exists(tokenId)) revert InvalidNote();
        
        Note storage note = notes[tokenId];
        if (note.fullyRepaid) revert NoteFullyRepaid();
        
        address noteOwner = ownerOf(tokenId);
        
        // Calculate current interest owed
        uint256 interestOwed = _calculateInterestOwed(note);
        
        uint256 interestPayment = 0;
        uint256 principalPayment = 0;
        
        if (amount <= interestOwed) {
            // All goes to interest
            interestPayment = amount;
        } else {
            // Pay all interest, rest goes to principal
            interestPayment = interestOwed;
            uint256 remaining = amount - interestOwed;
            uint256 remainingPrincipal = note.principal - note.principalRepaid;
            principalPayment = remaining > remainingPrincipal ? remainingPrincipal : remaining;
        }
        
        // Transfer USDT from payer to note owner
        usdt.safeTransferFrom(msg.sender, noteOwner, interestPayment + principalPayment);
        
        // Update note state
        note.interestPaid += interestPayment;
        note.principalRepaid += principalPayment;
        
        // Reset timestamp if principal was reduced (for interest recalculation on new lower principal)
        if (principalPayment > 0) {
            // Lock in current period interest before resetting timestamp
            uint256 remainingPrincipalBefore = note.principal - (note.principalRepaid - principalPayment);
            uint256 elapsed = block.timestamp - note.timestamp;
            uint256 currentPeriodInterest = (remainingPrincipalBefore * note.aprBps * elapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);
            note.interestAccrued += currentPeriodInterest;
            
            // Reset timestamp - future interest accrues on reduced principal
            note.timestamp = block.timestamp;
        }
        
        emit Repaid(tokenId, msg.sender, interestPayment, principalPayment);
        
        // Check if note is fully repaid (below dust threshold)
        uint256 principalLeft = note.principal - note.principalRepaid;
        if (principalLeft < DUST_THRESHOLD) {
            note.fullyRepaid = true;
            note.completedTimestamp = block.timestamp;
            emit NoteCompleted(tokenId, note.principalRepaid, note.interestPaid);
        }
    }
    
    /**
     * @notice Collect a completed tranche and send funds to cluster manager
     * @dev Can be collected when: (1) time has ended, OR (2) tranche is full
     *      Does NOT auto-start next tranche - that happens via deposit() lazy progression
     * @param trancheId The tranche to collect
     */
    function collectTranche(uint256 trancheId) external {
        Tranche storage tranche = tranches[trancheId];

        if (tranche.endTime == 0 && tranche.cap == 0) revert TrancheNonexistant();
        
        // Allow collection if: (1) ended by time OR (2) fully funded
        bool isEnded = tranche.endTime > 0 && block.timestamp >= tranche.endTime;
        bool isFull = tranche.totalDeposited >= tranche.cap;
        
        if (!isEnded && !isFull) revert TrancheNotEnded();
        if (tranche.collected) revert TrancheAlreadyCollected();
        
        tranche.collected = true;
        
        uint256 amount = tranche.totalDeposited;
        if (amount > 0) {
            usdt.safeTransfer(clusterManager, amount);
        }
        
        emit TrancheCollected(trancheId, amount);
        // Note: Next tranche auto-starts via _ensureCurrentTranche() in deposit()
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get complete information about a donation note
     * @param tokenId The note to query
     */
    function getNoteInfo(uint256 tokenId) external view returns (
        address owner,
        uint256 trancheId,
        uint256 aprBps,
        uint256 timestamp,
        uint256 interestOwed,
        uint256 interestPerSecond,
        uint256 principal,
        uint256 principalRepaid,
        uint256 interestPaid,
        uint256 interestAccrued,
        uint256 remainingPrincipal,
        uint256 totalRepaid,
        bool fullyRepaid,
        uint256 completedTimestamp
    ) {
        if (!_exists(tokenId)) revert InvalidNote();
        
        Note storage note = notes[tokenId];
        owner = ownerOf(tokenId);
        trancheId = note.trancheId;
        aprBps = note.aprBps;
        timestamp = note.timestamp;
        principal = note.principal;
        principalRepaid = note.principalRepaid;
        interestPaid = note.interestPaid;
        interestAccrued = note.interestAccrued;
        remainingPrincipal = principal - principalRepaid;
        totalRepaid = principalRepaid + interestPaid;
        fullyRepaid = note.fullyRepaid;
        completedTimestamp = note.completedTimestamp;
        
        if (fullyRepaid) {
            interestOwed = 0;
            interestPerSecond = 0;
        } else {
            interestOwed = _calculateInterestOwed(note);
            interestPerSecond = (remainingPrincipal * note.aprBps) / (BASIS_POINTS * SECONDS_PER_YEAR);
        }
    }
    
    /**
     * @notice Get current tranche information
     */
    function getCurrentTranche() external view returns (
        uint256 id,
        uint256 startTime,
        uint256 endTime,
        uint256 cap,
        uint256 totalDeposited,
        uint256 remaining,
        bool isActive,
        bool collected,
        uint256 totalMatched
    ) {
        Tranche storage tranche = tranches[currentTrancheId];
        id = tranche.id;
        startTime = tranche.startTime;
        endTime = tranche.endTime;
        cap = tranche.cap;
        totalDeposited = tranche.totalDeposited;
        remaining = cap > totalDeposited ? cap - totalDeposited : 0;
        isActive = _isTrancheActive(tranche);
        collected = tranche.collected;
        totalMatched = tranche.totalMatched;
    }
    
    /**
     * @notice Get tranche information by ID
     */
    function getTranche(uint256 trancheId) external view returns (
        uint256 startTime,
        uint256 endTime,
        uint256 cap,
        uint256 totalDeposited,
        bool collected,
        uint256 totalMatched
    ) {
        Tranche storage tranche = tranches[trancheId];
        startTime = tranche.startTime;
        endTime = tranche.endTime;
        cap = tranche.cap;
        totalDeposited = tranche.totalDeposited;
        collected = tranche.collected;
        totalMatched = tranche.totalMatched;
    }
    
    /**
     * @notice Check remaining capacity in current tranche
     */
    function getRemainingCapacity() external view returns (uint256) {
        Tranche storage tranche = tranches[currentTrancheId];
        if (!_isTrancheActive(tranche)) return 0;
        return tranche.cap - tranche.totalDeposited;
    }
    
    /**
     * @notice Get the effective minimum deposit for current tranche
     * @dev Returns MIN_DEPOSIT normally, but (remaining/2 + 0.001) when low capacity
     *      This allows the tranche to be fully filled with matching
     */
    function getEffectiveMinDeposit() external view returns (uint256) {
        Tranche storage tranche = tranches[currentTrancheId];
        uint256 remaining = tranche.cap - tranche.totalDeposited;
        return _getEffectiveMinDeposit(remaining);
    }
    
    /**
     * @notice Preview expected matching for a deposit amount
     * @param amount The deposit amount to preview
     * @return matchAmount The amount that would be matched
     * @return matchPercentBps The match percentage in basis points (10000 = 100%)
     */
    function getExpectedMatch(uint256 amount) external view returns (
        uint256 matchAmount,
        uint256 matchPercentBps
    ) {
        if (vault == address(0) || amount == 0) {
            return (0, 0);
        }
        
        Tranche storage tranche = tranches[currentTrancheId];
        uint256 remaining = tranche.cap - tranche.totalDeposited;
        
        // Cap deposit amount to remaining capacity
        uint256 actualDeposit = amount > remaining ? remaining : amount;
        
        // Calculate remaining after user deposit
        uint256 remainingAfterDeposit = remaining - actualDeposit;
        
        // If no room for matching, return zero
        if (remainingAfterDeposit == 0) {
            return (0, 0);
        }
        
        // Calculate potential match amount (limited by capacity)
        uint256 potentialMatch = actualDeposit > remainingAfterDeposit 
            ? remainingAfterDeposit 
            : actualDeposit;
        
        // Check vault balance
        uint256 vaultBalance = usdt.balanceOf(vault);
        
        // Final match is minimum of potential and vault balance
        matchAmount = potentialMatch > vaultBalance ? vaultBalance : potentialMatch;
        
        // Calculate percentage (avoid division by zero)
        if (actualDeposit > 0 && matchAmount > 0) {
            matchPercentBps = (matchAmount * BASIS_POINTS) / actualDeposit;
        } else {
            matchPercentBps = 0;
        }
    }
    
    /**
     * @notice Get all scheduled tranche times
     * @return startTimes Array of scheduled start timestamps
     * @return endTimes Array of scheduled end timestamps (start + TRANCHE_DURATION)
     */
    function getScheduledTranches() external view returns (
        uint256[] memory startTimes,
        uint256[] memory endTimes
    ) {
        uint256 len = _scheduledStartTimes.length();
        startTimes = new uint256[](len);
        endTimes = new uint256[](len);
        
        for (uint256 i = 0; i < len; i++) {
            uint256 startTime = uint256(_scheduledStartTimes.at(i));
            startTimes[i] = startTime;
            endTimes[i] = startTime + TRANCHE_DURATION;
        }
    }
    
    /**
     * @notice Get count of scheduled tranches waiting to start
     */
    function scheduledTrancheCount() external view returns (uint256) {
        return _scheduledStartTimes.length();
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Ensure we're on the correct current tranche based on time
     * @dev Auto-collects previous tranche if needed and starts next tranche
     *      Called at the start of deposit() for lazy progression
     */
    function _ensureCurrentTranche() internal {
        Tranche storage current = tranches[currentTrancheId];
        
        // Check if current tranche has ended and we have scheduled tranches
        if (current.endTime > 0 && block.timestamp >= current.endTime && !_scheduledStartTimes.empty()) {
            // Auto-collect previous tranche if not collected
            if (!current.collected) {
                current.collected = true;
                uint256 amount = current.totalDeposited;
                if (amount > 0) {
                    usdt.safeTransfer(clusterManager, amount);
                }
                emit TrancheCollected(currentTrancheId, amount);
            }
            
            // Start next tranche if its scheduled time has arrived
            uint256 nextStart = uint256(_scheduledStartTimes.front());
            if (block.timestamp >= nextStart) {
                _startNewTrancheAt(nextStart);
            }
        }
    }
    
    /**
     * @notice Start a new tranche at the specified time
     * @param startTimestamp The start time for the new tranche
     */
    function _startNewTrancheAt(uint256 startTimestamp) internal {
        if (_scheduledStartTimes.empty()) revert NoTranchesScheduled();
        
        // Pop first scheduled time from queue - O(1) operation
        _scheduledStartTimes.popFront();
        
        currentTrancheId++;
        Tranche storage tranche = tranches[currentTrancheId];
        tranche.id = currentTrancheId;
        tranche.startTime = startTimestamp;
        tranche.endTime = startTimestamp + TRANCHE_DURATION;
        tranche.cap = DEFAULT_TRANCHE_CAP;
        
        emit TrancheStarted(currentTrancheId, startTimestamp, tranche.endTime, tranche.cap);
    }
    
    function _mintNote(address to, uint256 amount) internal returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        _mint(to, tokenId);
        
        notes[tokenId] = Note({
            trancheId: currentTrancheId,
            principal: amount,
            aprBps: defaultAprBps,
            timestamp: block.timestamp,
            principalRepaid: 0,
            interestPaid: 0,
            interestAccrued: 0,
            fullyRepaid: false,
            completedTimestamp: 0
        });
    }
    
    function _attemptMatch(uint256 amount) internal returns (bool) {
        if (vault == address(0)) return false;
        if (amount == 0) return false;
        
        // Defensive check: ensure we don't exceed tranche capacity
        Tranche storage tranche = tranches[currentTrancheId];
        uint256 remaining = tranche.cap - tranche.totalDeposited;
        if (remaining == 0) return false;
        
        // Cap match amount to remaining capacity
        uint256 matchAmount = amount > remaining ? remaining : amount;
        
        uint256 vaultBalance = usdt.balanceOf(vault);
        if (vaultBalance < matchAmount) {
            // Reset match amount to vault balance
            matchAmount = vaultBalance;
        }
        
        // Skip if match amount is zero (vault empty)
        if (matchAmount == 0) return false;
        
        // Transfer matching funds from vault
        usdt.safeTransferFrom(vault, address(this), matchAmount);
        
        // Update tranche totals
        tranche.totalDeposited += matchAmount;
        tranche.totalMatched += matchAmount;
        
        // Mint note to vault
        // Note: Vault may receive notes below MIN_DEPOSIT when filling remaining capacity.
        // This is intentional - MIN_DEPOSIT only applies to user deposits, not matching.
        uint256 matchedTokenId = _mintNote(vault, matchAmount);
        
        emit Deposited(matchedTokenId, vault, matchAmount, currentTrancheId, true);
        
        return true;
    }
    
    function _calculateInterestOwed(Note storage note) internal view returns (uint256) {
        if (note.fullyRepaid) return 0;
        
        uint256 remainingPrincipal = note.principal - note.principalRepaid;
        uint256 elapsed = block.timestamp - note.timestamp;
        
        // Interest for current period = remaining principal * apr * time / (bps * seconds_per_year)
        uint256 currentPeriodInterest = (remainingPrincipal * note.aprBps * elapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);
        
        // Total interest owed = locked-in accrued + current period - already paid
        uint256 totalAccrued = note.interestAccrued + currentPeriodInterest;
        
        // Return net interest owed (can't be negative)
        if (note.interestPaid >= totalAccrued) return 0;
        return totalAccrued - note.interestPaid;
    }
    
    function _isTrancheActive(Tranche storage tranche) internal view returns (bool) {
        return tranche.startTime > 0 && 
               block.timestamp >= tranche.startTime && 
               block.timestamp < tranche.endTime &&
               tranche.totalDeposited < tranche.cap;
    }
    
    /**
     * @notice Calculate effective minimum deposit based on remaining capacity
     * @dev When remaining < MIN_DEPOSIT * 2, returns (remaining / 2) + 0.001 ether
     *      This allows tranches to be fully filled with matching
     * @param remaining The remaining capacity in the tranche
     */
    function _getEffectiveMinDeposit(uint256 remaining) internal pure returns (uint256) {
        // If plenty of room for deposit + matching, use standard MIN_DEPOSIT
        if (remaining >= MIN_DEPOSIT * 2) {
            return MIN_DEPOSIT;
        }
        // When low capacity, allow half remaining + 0.001 to prevent dust
        // User deposits half, matching fills the other half
        return (remaining / 2) + 0.001 ether;
    }
    
    function _exists(uint256 tokenId) internal view returns (bool) {
        return notes[tokenId].timestamp > 0;
    }
    
    // ============ Overrides ============
    
    /**
     * @notice Override supportsInterface for ERC721Enumerable compatibility
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
