import { useState, useEffect, useCallback, useRef } from 'react';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { toast } from 'sonner';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { ADDRESSES } from '@/lib/config';
import { DonationTrancheABI } from '@/lib/abi/DonationTranche';

interface ScheduledTrancheData {
  startTime: number;
  endTime: number;
}

interface Props {
  currentTrancheId: number;
  scheduledTranches: ScheduledTrancheData[];
  onTrancheStarted?: () => void;
}

function formatCountdown(seconds: number) {
  if (seconds <= 0) return 'Starting now';
  
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  
  if (days > 0) {
    return `${days}d ${hours}h ${minutes}m ${secs}s`;
  } else if (hours > 0) {
    return `${hours}h ${minutes}m ${secs}s`;
  } else if (minutes > 0) {
    return `${minutes}m ${secs}s`;
  } else {
    return `${secs}s`;
  }
}

function formatDate(timestamp: number) {
  return new Date(timestamp * 1000).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function ScheduledTranches({ currentTrancheId, scheduledTranches, onTrancheStarted }: Props) {
  const [now, setNow] = useState(() => Date.now() / 1000);
  const trancheAddress = ADDRESSES.DONATION_TRANCHE;
  
  // Live-updating countdown
  useEffect(() => {
    const timer = setInterval(() => {
      setNow(Date.now() / 1000);
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  // Check if current tranche is collected (required before starting next)
  const { data: currentTrancheData } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'getCurrentTranche',
    query: { enabled: !!trancheAddress },
  });

  // Parse current tranche to check if collected
  const currentTranche = currentTrancheData ? {
    collected: (currentTrancheData as readonly [bigint, bigint, bigint, bigint, bigint, bigint, boolean, boolean, bigint])[7],
    isActive: (currentTrancheData as readonly [bigint, bigint, bigint, bigint, bigint, bigint, boolean, boolean, bigint])[6],
  } : null;

  // Write contract hook for starting next tranche
  const {
    writeContract: startNextTranche,
    data: startTxHash,
    isPending: isStartPending,
    error: startError,
  } = useWriteContract();

  // Transaction receipt
  const { isSuccess: startSuccess } = useWaitForTransactionReceipt({ hash: startTxHash });

  // Handle errors
  useEffect(() => {
    if (startError) {
      toast.error('Failed to start tranche', { description: startError.message.slice(0, 100) });
    }
  }, [startError]);

  // Track previous success state to detect transitions
  const prevStartSuccess = useRef(false);

  // Handle success
  const handleStartSuccess = useCallback(() => {
    toast.success('Tranche started successfully!');
    onTrancheStarted?.();
  }, [onTrancheStarted]);

  useEffect(() => {
    if (startSuccess && !prevStartSuccess.current) {
      queueMicrotask(handleStartSuccess);
    }
    prevStartSuccess.current = startSuccess;
  }, [startSuccess, handleStartSuccess]);

  // Handler to start the next tranche
  const handleStartTranche = () => {
    if (!trancheAddress) return;
    startNextTranche({
      address: trancheAddress,
      abi: DonationTrancheABI,
      functionName: 'startNextTranche',
    });
  };
  
  if (scheduledTranches.length === 0) {
    return null;
  }

  // Check if the first scheduled tranche can be started
  // Show Start button when:
  // 1. Current tranche is collected, AND
  // 2. Browser time has passed scheduled start time OR current tranche is not active (ended)
  // Note: The contract will validate that blockchain time has passed the scheduled time.
  // We use isActive as a proxy for whether blockchain time has passed the current tranche end time.
  const firstTranche = scheduledTranches[0];
  const timeUntilFirstStart = firstTranche.startTime - now;
  const browserTimeReady = timeUntilFirstStart <= 0;
  const currentTrancheEnded = currentTranche?.isActive === false;
  const canStartNext = currentTranche?.collected === true && (browserTimeReady || currentTrancheEnded);

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg">Upcoming Tranches</CardTitle>
        <p className="text-sm text-[var(--text-muted)]">
          {scheduledTranches.length} tranche{scheduledTranches.length !== 1 ? 's' : ''} scheduled
        </p>
      </CardHeader>
      <CardContent>
        <div className="space-y-3">
          {scheduledTranches.map((tranche, index) => {
            const trancheNumber = currentTrancheId + index + 1;
            const timeUntilStart = tranche.startTime - now;
            const isStartingSoon = timeUntilStart <= 86400 && timeUntilStart > 0; // Within 24 hours
            const isReadyToStart = timeUntilStart <= 0;
            const isFirstAndCanStart = index === 0 && canStartNext;
            
            return (
              <div 
                key={index}
                className={`flex items-center justify-between p-3 rounded-lg ${
                  isFirstAndCanStart
                    ? 'bg-[var(--gold)]/20 border border-[var(--gold)]/50'
                    : isStartingSoon 
                      ? 'bg-[var(--gold)]/10 border border-[var(--gold)]/30' 
                      : isReadyToStart
                        ? 'bg-[var(--aqua)]/10 border border-[var(--aqua)]/30'
                        : 'bg-[var(--charcoal)]'
                }`}
              >
                <div>
                  <p className="font-semibold text-[var(--text-primary)]">
                    Tranche #{trancheNumber}
                  </p>
                  <p className="text-xs text-[var(--text-muted)]">
                    {formatDate(tranche.startTime)} - {formatDate(tranche.endTime)}
                  </p>
                </div>
                <div className="text-right flex items-center gap-3">
                  {isFirstAndCanStart ? (
                    <Button
                      variant="primary"
                      size="sm"
                      onClick={handleStartTranche}
                      disabled={isStartPending}
                    >
                      {isStartPending ? 'Starting...' : 'Start Tranche'}
                    </Button>
                  ) : isReadyToStart && index === 0 ? (
                    <div>
                      <p className="text-xs text-[var(--text-muted)]">
                        Waiting for collection
                      </p>
                      <p className="text-[var(--aqua)] font-mono text-sm">
                        Ready to start
                      </p>
                    </div>
                  ) : (
                    <div>
                      <p className="text-xs text-[var(--text-muted)]">
                        {timeUntilStart > 0 ? 'Starts in' : 'Ready'}
                      </p>
                      <p className={`font-mono ${isStartingSoon ? 'text-[var(--gold)]' : 'text-[var(--text-secondary)]'}`}>
                        {formatCountdown(timeUntilStart)}
                      </p>
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}
