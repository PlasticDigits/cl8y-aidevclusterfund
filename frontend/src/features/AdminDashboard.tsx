import { useState, useEffect, useCallback, useRef } from 'react';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { toast } from 'sonner';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { ADDRESSES } from '@/lib/config';
import { DonationTrancheABI } from '@/lib/abi/DonationTranche';
import { isAddress } from 'viem';

export function AdminDashboard() {
  const trancheAddress = ADDRESSES.DONATION_TRANCHE;

  // Form state
  const [trancheCount, setTrancheCount] = useState('1');
  const [newAprPercent, setNewAprPercent] = useState('');
  const [newVaultAddress, setNewVaultAddress] = useState('');

  // Read contract state
  const { data: firstTrancheStarted, refetch: refetchFirstTranche } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'firstTrancheStarted',
    query: { enabled: !!trancheAddress },
  });

  const { data: scheduledTrancheCount, refetch: refetchScheduled } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'scheduledTrancheCount',
    query: { enabled: !!trancheAddress },
  });

  const { data: defaultAprBps, refetch: refetchApr } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'defaultAprBps',
    query: { enabled: !!trancheAddress },
  });

  const { data: vaultAddress, refetch: refetchVault } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'vault',
    query: { enabled: !!trancheAddress },
  });

  const { data: currentTrancheId, refetch: refetchCurrentTranche } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'currentTrancheId',
    query: { enabled: !!trancheAddress },
  });

  // Get current tranche info to check if ended/collected
  const { data: currentTrancheData } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'getCurrentTranche',
    query: { enabled: !!trancheAddress },
  });

  // Parse current tranche info
  const currentTranche = currentTrancheData ? {
    id: (currentTrancheData as readonly [bigint, bigint, bigint, bigint, bigint, bigint, boolean, boolean, bigint])[0],
    endTime: (currentTrancheData as readonly [bigint, bigint, bigint, bigint, bigint, bigint, boolean, boolean, bigint])[2],
    isActive: (currentTrancheData as readonly [bigint, bigint, bigint, bigint, bigint, bigint, boolean, boolean, bigint])[6],
    collected: (currentTrancheData as readonly [bigint, bigint, bigint, bigint, bigint, bigint, boolean, boolean, bigint])[7],
  } : null;

  // Check if startNextTranche can be called
  const canStartNextTranche = firstTrancheStarted && 
    currentTranche && 
    !currentTranche.isActive && 
    currentTranche.collected && 
    scheduledTrancheCount && Number(scheduledTrancheCount) > 0;

  // Write contract hooks
  const { 
    writeContract: startFirstTranche, 
    data: startTxHash,
    isPending: isStartPending,
    error: startError,
  } = useWriteContract();

  const { 
    writeContract: scheduleTranches, 
    data: scheduleTxHash,
    isPending: isSchedulePending,
    error: scheduleError,
  } = useWriteContract();

  const { 
    writeContract: setApr, 
    data: aprTxHash,
    isPending: isAprPending,
    error: aprError,
  } = useWriteContract();

  const { 
    writeContract: setVault, 
    data: vaultTxHash,
    isPending: isVaultPending,
    error: vaultError,
  } = useWriteContract();

  const { 
    writeContract: startNextTranche, 
    data: startNextTxHash,
    isPending: isStartNextPending,
    error: startNextError,
  } = useWriteContract();

  // Transaction receipts
  const { isSuccess: startSuccess } = useWaitForTransactionReceipt({ hash: startTxHash });
  const { isSuccess: scheduleSuccess } = useWaitForTransactionReceipt({ hash: scheduleTxHash });
  const { isSuccess: aprSuccess } = useWaitForTransactionReceipt({ hash: aprTxHash });
  const { isSuccess: vaultSuccess } = useWaitForTransactionReceipt({ hash: vaultTxHash });
  const { isSuccess: startNextSuccess } = useWaitForTransactionReceipt({ hash: startNextTxHash });

  // Handle errors
  useEffect(() => {
    if (startError) toast.error('Failed to start tranche', { description: startError.message.slice(0, 100) });
    if (scheduleError) toast.error('Failed to schedule tranches', { description: scheduleError.message.slice(0, 100) });
    if (aprError) toast.error('Failed to update APR', { description: aprError.message.slice(0, 100) });
    if (vaultError) toast.error('Failed to update vault', { description: vaultError.message.slice(0, 100) });
    if (startNextError) toast.error('Failed to start next tranche', { description: startNextError.message.slice(0, 100) });
  }, [startError, scheduleError, aprError, vaultError, startNextError]);

  // Track previous success states to detect transitions
  const prevStartSuccess = useRef(false);
  const prevScheduleSuccess = useRef(false);
  const prevAprSuccess = useRef(false);
  const prevVaultSuccess = useRef(false);
  const prevStartNextSuccess = useRef(false);

  // Stable success handlers using useCallback
  const handleStartSuccess = useCallback(() => {
    toast.success('First tranche started!');
    refetchFirstTranche();
  }, [refetchFirstTranche]);

  const handleScheduleSuccess = useCallback(() => {
    toast.success(`Scheduled additional tranches`);
    refetchScheduled();
    setTrancheCount('1');
  }, [refetchScheduled]);

  const handleAprSuccess = useCallback(() => {
    toast.success('APR updated successfully');
    refetchApr();
    setNewAprPercent('');
  }, [refetchApr]);

  const handleVaultSuccess = useCallback(() => {
    toast.success('Vault address updated');
    refetchVault();
    setNewVaultAddress('');
  }, [refetchVault]);

  const handleStartNextSuccess = useCallback(() => {
    toast.success('Next tranche started!');
    refetchCurrentTranche();
    refetchScheduled();
  }, [refetchCurrentTranche, refetchScheduled]);

  // Handle success state transitions - use queueMicrotask to defer setState
  useEffect(() => {
    if (startSuccess && !prevStartSuccess.current) {
      queueMicrotask(handleStartSuccess);
    }
    prevStartSuccess.current = startSuccess;
  }, [startSuccess, handleStartSuccess]);

  useEffect(() => {
    if (scheduleSuccess && !prevScheduleSuccess.current) {
      queueMicrotask(handleScheduleSuccess);
    }
    prevScheduleSuccess.current = scheduleSuccess;
  }, [scheduleSuccess, handleScheduleSuccess]);

  useEffect(() => {
    if (aprSuccess && !prevAprSuccess.current) {
      queueMicrotask(handleAprSuccess);
    }
    prevAprSuccess.current = aprSuccess;
  }, [aprSuccess, handleAprSuccess]);

  useEffect(() => {
    if (vaultSuccess && !prevVaultSuccess.current) {
      queueMicrotask(handleVaultSuccess);
    }
    prevVaultSuccess.current = vaultSuccess;
  }, [vaultSuccess, handleVaultSuccess]);

  useEffect(() => {
    if (startNextSuccess && !prevStartNextSuccess.current) {
      queueMicrotask(handleStartNextSuccess);
    }
    prevStartNextSuccess.current = startNextSuccess;
  }, [startNextSuccess, handleStartNextSuccess]);

  // Action handlers
  const handleStartFirstTranche = () => {
    if (!trancheAddress) return;
    // Start immediately with current timestamp
    const currentTimestamp = BigInt(Math.floor(Date.now() / 1000));
    startFirstTranche({
      address: trancheAddress,
      abi: DonationTrancheABI,
      functionName: 'startFirstTranche',
      args: [currentTimestamp],
    });
  };

  const handleStartNextTranche = () => {
    if (!trancheAddress) return;
    startNextTranche({
      address: trancheAddress,
      abi: DonationTrancheABI,
      functionName: 'startNextTranche',
    });
  };

  const handleScheduleTranches = () => {
    if (!trancheAddress) return;
    const count = parseInt(trancheCount);
    if (isNaN(count) || count <= 0) {
      toast.error('Please enter a valid number of tranches');
      return;
    }
    // Auto-calculate start time (0 = continue from last scheduled)
    scheduleTranches({
      address: trancheAddress,
      abi: DonationTrancheABI,
      functionName: 'scheduleAdditionalTranches',
      args: [BigInt(count), BigInt(0)],
    });
  };

  const handleSetApr = () => {
    if (!trancheAddress) return;
    const aprPercent = parseFloat(newAprPercent);
    if (isNaN(aprPercent) || aprPercent < 0 || aprPercent > 100) {
      toast.error('Please enter a valid APR percentage (0-100)');
      return;
    }
    const bps = BigInt(Math.round(aprPercent * 100)); // Convert percent to basis points
    setApr({
      address: trancheAddress,
      abi: DonationTrancheABI,
      functionName: 'setDefaultApr',
      args: [bps],
    });
  };

  const handleSetVault = () => {
    if (!trancheAddress) return;
    if (!isAddress(newVaultAddress)) {
      toast.error('Please enter a valid address');
      return;
    }
    setVault({
      address: trancheAddress,
      abi: DonationTrancheABI,
      functionName: 'setVault',
      args: [newVaultAddress as `0x${string}`],
    });
  };

  if (!trancheAddress) {
    return (
      <Card>
        <CardContent className="py-8 text-center text-[var(--text-muted)]">
          Contract not deployed
        </CardContent>
      </Card>
    );
  }

  const currentAprPercent = defaultAprBps ? Number(defaultAprBps) / 100 : 0;

  return (
    <Card className="border-[var(--gold)]/30 bg-[var(--gold)]/5">
      <CardHeader>
        <CardTitle className="text-[var(--gold)]">Admin Dashboard</CardTitle>
        <p className="text-sm text-[var(--text-muted)]">
          Manage tranche settings and contract configuration
        </p>
      </CardHeader>

      <CardContent className="space-y-6">
        {/* Current State */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 p-4 bg-[var(--charcoal)] rounded-lg">
          <div>
            <p className="text-xs text-[var(--text-muted)]">First Tranche</p>
            <p className="font-semibold text-[var(--text-primary)]">
              {firstTrancheStarted ? 'Started' : 'Not Started'}
            </p>
          </div>
          <div>
            <p className="text-xs text-[var(--text-muted)]">Current Tranche</p>
            <p className="font-semibold text-[var(--text-primary)]">
              #{currentTrancheId?.toString() || '0'}
            </p>
          </div>
          <div>
            <p className="text-xs text-[var(--text-muted)]">Scheduled</p>
            <p className="font-semibold text-[var(--text-primary)]">
              {scheduledTrancheCount?.toString() || '0'} tranches
            </p>
          </div>
          <div>
            <p className="text-xs text-[var(--text-muted)]">Current APR</p>
            <p className="font-semibold text-[var(--gold)]">
              {currentAprPercent.toFixed(1)}%
            </p>
          </div>
        </div>

        {/* Vault Address */}
        <div className="p-4 bg-[var(--charcoal)] rounded-lg">
          <p className="text-xs text-[var(--text-muted)] mb-1">Vault Address</p>
          <p className="font-mono text-sm text-[var(--text-secondary)] break-all">
            {vaultAddress || 'Not set'}
          </p>
        </div>

        {/* Actions */}
        <div className="space-y-4">
          {/* Start First Tranche */}
          {!firstTrancheStarted && (
            <div className="flex items-center gap-4">
              <button
                onClick={handleStartFirstTranche}
                disabled={isStartPending}
                className="px-4 py-2 rounded-lg bg-[var(--gold)] text-[var(--black)] font-semibold hover:bg-[var(--gold)]/90 disabled:opacity-50 transition-colors"
              >
                {isStartPending ? 'Starting...' : 'Start First Tranche'}
              </button>
              <span className="text-sm text-[var(--text-muted)]">
                Initializes the first 2-week fundraising tranche
              </span>
            </div>
          )}

          {/* Start Next Tranche */}
          {firstTrancheStarted && (
            <div className="flex items-center gap-4">
              <button
                onClick={handleStartNextTranche}
                disabled={isStartNextPending || !canStartNextTranche}
                className="px-4 py-2 rounded-lg bg-[var(--gold)] text-[var(--black)] font-semibold hover:bg-[var(--gold)]/90 disabled:opacity-50 transition-colors"
              >
                {isStartNextPending ? 'Starting...' : 'Start Next Tranche'}
              </button>
              <span className="text-sm text-[var(--text-muted)]">
                {!canStartNextTranche 
                  ? currentTranche?.isActive 
                    ? 'Current tranche still active'
                    : !currentTranche?.collected
                      ? 'Collect current tranche first'
                      : scheduledTrancheCount && Number(scheduledTrancheCount) === 0
                        ? 'No scheduled tranches'
                        : 'Resume after gap in tranches'
                  : 'Resume after gap in tranches'}
              </span>
            </div>
          )}

          {/* Schedule Additional Tranches */}
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <input
                type="number"
                min="1"
                value={trancheCount}
                onChange={(e) => setTrancheCount(e.target.value)}
                className="w-20 px-3 py-2 rounded-lg bg-[var(--obsidian)] border border-[var(--charcoal)] text-[var(--text-primary)] focus:outline-none focus:ring-2 focus:ring-[var(--gold)]/50"
              />
              <button
                onClick={handleScheduleTranches}
                disabled={isSchedulePending}
                className="px-4 py-2 rounded-lg border border-[var(--gold)] text-[var(--gold)] hover:bg-[var(--gold)]/10 disabled:opacity-50 transition-colors"
              >
                {isSchedulePending ? 'Scheduling...' : 'Schedule Tranches'}
              </button>
            </div>
            <span className="text-sm text-[var(--text-muted)]">
              Add more tranches to the queue
            </span>
          </div>

          {/* Update APR */}
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <input
                type="number"
                step="0.1"
                min="0"
                max="100"
                placeholder={`${currentAprPercent}%`}
                value={newAprPercent}
                onChange={(e) => setNewAprPercent(e.target.value)}
                className="w-24 px-3 py-2 rounded-lg bg-[var(--obsidian)] border border-[var(--charcoal)] text-[var(--text-primary)] placeholder:text-[var(--text-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--gold)]/50"
              />
              <span className="text-[var(--text-muted)]">%</span>
              <button
                onClick={handleSetApr}
                disabled={isAprPending || !newAprPercent}
                className="px-4 py-2 rounded-lg border border-[var(--charcoal)] text-[var(--text-secondary)] hover:bg-[var(--charcoal)] disabled:opacity-50 transition-colors"
              >
                {isAprPending ? 'Updating...' : 'Set APR'}
              </button>
            </div>
            <span className="text-sm text-[var(--text-muted)]">
              APR for new notes (current: {currentAprPercent}%)
            </span>
          </div>

          {/* Update Vault */}
          <div className="flex flex-col md:flex-row md:items-center gap-4">
            <div className="flex items-center gap-2 flex-1">
              <input
                type="text"
                placeholder="0x..."
                value={newVaultAddress}
                onChange={(e) => setNewVaultAddress(e.target.value)}
                className="flex-1 min-w-0 px-3 py-2 rounded-lg bg-[var(--obsidian)] border border-[var(--charcoal)] text-[var(--text-primary)] placeholder:text-[var(--text-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--gold)]/50"
              />
              <button
                onClick={handleSetVault}
                disabled={isVaultPending || !newVaultAddress}
                className="px-4 py-2 rounded-lg border border-[var(--charcoal)] text-[var(--text-secondary)] hover:bg-[var(--charcoal)] disabled:opacity-50 transition-colors whitespace-nowrap"
              >
                {isVaultPending ? 'Updating...' : 'Set Vault'}
              </button>
            </div>
            <span className="text-sm text-[var(--text-muted)]">
              Update matching vault address
            </span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
