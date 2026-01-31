import { useState, useEffect } from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';

interface ScheduledTrancheData {
  startTime: number;
  endTime: number;
}

interface Props {
  currentTrancheId: number;
  scheduledTranches: ScheduledTrancheData[];
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

export function ScheduledTranches({ currentTrancheId, scheduledTranches }: Props) {
  const [now, setNow] = useState(() => Date.now() / 1000);
  
  // Live-updating countdown
  useEffect(() => {
    const timer = setInterval(() => {
      setNow(Date.now() / 1000);
    }, 1000);
    return () => clearInterval(timer);
  }, []);
  
  if (scheduledTranches.length === 0) {
    return null;
  }

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
            
            return (
              <div 
                key={index}
                className={`flex items-center justify-between p-3 rounded-lg ${
                  isStartingSoon 
                    ? 'bg-[var(--gold)]/10 border border-[var(--gold)]/30' 
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
                <div className="text-right">
                  <p className="text-xs text-[var(--text-muted)]">
                    {timeUntilStart > 0 ? 'Starts in' : 'Started'}
                  </p>
                  <p className={`font-mono ${isStartingSoon ? 'text-[var(--gold)]' : 'text-[var(--text-secondary)]'}`}>
                    {formatCountdown(timeUntilStart)}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}
