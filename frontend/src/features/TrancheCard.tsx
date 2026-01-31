import { useState, useEffect } from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { ProgressBar } from '@/components/ui/ProgressBar';
import { Button } from '@/components/ui/Button';
import { TokenIcon } from '@/components/ui/TokenIcon';
import { TRANCHE_CAP_USDT, DEFAULT_APR_PERCENT } from '@/lib/config';

interface TrancheData {
  id: number;
  startTime: number;
  endTime: number;
  cap: number;
  totalDeposited: number;
  isActive: boolean;
  collected: boolean;
}

interface Props {
  tranche: TrancheData | null;
  onDeposit?: () => void;
  isConnected: boolean;
}

function formatCountdown(seconds: number) {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  
  if (days > 0) {
    return `${days}d ${hours}h ${minutes}m ${secs}s`;
  } else if (hours > 0) {
    return `${hours}h ${minutes}m ${secs}s`;
  } else {
    return `${minutes}m ${secs}s`;
  }
}

export function TrancheCard({ tranche, onDeposit, isConnected }: Props) {
  const [now, setNow] = useState(() => Date.now() / 1000);
  
  // Live-updating countdown
  useEffect(() => {
    const timer = setInterval(() => {
      setNow(Date.now() / 1000);
    }, 1000);
    return () => clearInterval(timer);
  }, []);
  
  if (!tranche) {
    return (
      <Card variant="premium" className="text-center py-12">
        <div className="animate-pulse space-y-4">
          <div className="h-6 w-32 bg-[var(--charcoal)] rounded mx-auto" />
          <div className="h-4 w-48 bg-[var(--charcoal)] rounded mx-auto" />
          <div className="h-2 w-full bg-[var(--charcoal)] rounded" />
          <div className="grid grid-cols-3 gap-4 mt-6">
            <div className="h-20 bg-[var(--charcoal)] rounded" />
            <div className="h-20 bg-[var(--charcoal)] rounded" />
            <div className="h-20 bg-[var(--charcoal)] rounded" />
          </div>
        </div>
        <p className="text-[var(--text-secondary)] mt-4">
          No active tranche. Check back soon!
        </p>
      </Card>
    );
  }

  const timeRemaining = Math.max(0, tranche.endTime - now);
  const isFull = tranche.totalDeposited >= (tranche.cap || TRANCHE_CAP_USDT);
  
  // Determine status
  let status = 'Active';
  let statusColor = 'text-green-400';
  if (tranche.collected) {
    status = 'Collected';
    statusColor = 'text-[var(--text-muted)]';
  } else if (isFull) {
    status = 'Full - Ready for Collection';
    statusColor = 'text-[var(--gold)]';
  } else if (!tranche.isActive && timeRemaining <= 0) {
    status = 'Ended';
    statusColor = 'text-[var(--text-muted)]';
  }

  const cap = tranche.cap || TRANCHE_CAP_USDT;
  const communityDeposited = tranche.totalDeposited / 2;
  const matchedDeposited = tranche.totalDeposited / 2;
  const communityCap = cap / 2;
  const servicesValue = tranche.totalDeposited * 1.5;

  return (
    <Card variant="premium">
      <CardHeader>
        <div className="flex justify-between items-start">
          <div>
            <CardTitle>Tranche #{tranche.id}</CardTitle>
            <p className={`text-sm mt-1 ${statusColor}`}>
              {status}
            </p>
          </div>
          {tranche.isActive && timeRemaining > 0 && (
            <div className="text-right">
              <p className="text-sm text-[var(--text-muted)]">Time Remaining</p>
              <p className="font-mono text-[var(--gold)]">
                {formatCountdown(timeRemaining)}
              </p>
            </div>
          )}
        </div>
      </CardHeader>

      <CardContent>
        <div className="space-y-6">
          {/* Progress */}
          <div>
            <div className="flex justify-between text-sm mb-2">
              <span className="text-[var(--text-secondary)]">Tranche Progress</span>
              <span className="text-[var(--gold)] font-mono">
                {DEFAULT_APR_PERCENT}% APR
              </span>
            </div>
            <ProgressBar
              value={tranche.totalDeposited}
              max={cap}
            />
          </div>

          {/* Breakdown - responsive grid */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-center">
            <div className="p-3 bg-[var(--charcoal)] rounded-lg relative overflow-hidden">
              <div className="absolute top-2 right-2 opacity-20">
                <TokenIcon token="USDT" size="lg" />
              </div>
              <p className="text-xs text-[var(--text-muted)] mb-1">Community</p>
              <p className="font-mono text-[var(--text-primary)] flex items-center justify-center gap-1">
                <TokenIcon token="USDT" size="sm" />
                {communityDeposited.toLocaleString()}
              </p>
              <p className="text-xs text-[var(--text-muted)]">
                of {communityCap.toLocaleString()}
              </p>
            </div>
            <div className="p-3 bg-[var(--charcoal)] rounded-lg relative overflow-hidden">
              <div className="absolute top-2 right-2 opacity-20">
                <TokenIcon token="CZODIAC" size="lg" />
              </div>
              <p className="text-xs text-[var(--text-muted)] mb-1">CZodiac Match</p>
              <p className="font-mono text-[var(--aqua)] flex items-center justify-center gap-1">
                <TokenIcon token="USDT" size="sm" />
                {matchedDeposited.toLocaleString()}
              </p>
              <p className="text-xs text-[var(--text-muted)]">1:1 Matched</p>
            </div>
            <div className="p-3 bg-[var(--charcoal)] rounded-lg relative overflow-hidden">
              <div className="absolute top-2 right-2 opacity-20">
                <TokenIcon token="CL8Y" size="lg" />
              </div>
              <p className="text-xs text-[var(--text-muted)] mb-1">Ceramic Services</p>
              <p className="font-mono text-[var(--ember)] flex items-center justify-center gap-1">
                <span className="text-[var(--ember)]">$</span>
                {servicesValue.toLocaleString()}
              </p>
              <p className="text-xs text-[var(--text-muted)]">1.5x QA+Audit</p>
            </div>
          </div>

          {/* Deposit Button */}
          {tranche.isActive && (
            <div className="pt-4">
              {isConnected ? (
                <Button
                  variant="primary"
                  size="lg"
                  className="w-full"
                  onClick={onDeposit}
                >
                  Contribute USDT
                </Button>
              ) : (
                <Button
                  variant="secondary"
                  size="lg"
                  className="w-full"
                  onClick={onDeposit}
                >
                  Connect Wallet to Contribute
                </Button>
              )}
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
