interface Props {
  value: number;
  max: number;
  className?: string;
  showLabel?: boolean;
  color?: 'gold' | 'aqua';
}

export function ProgressBar({
  value,
  max,
  className = '',
  showLabel = true,
  color = 'gold',
}: Props) {
  const percentage = max > 0 ? Math.min((value / max) * 100, 100) : 0;
  
  const colorStyles = {
    gold: 'bg-gradient-to-r from-[var(--gold-dark)] to-[var(--gold)]',
    aqua: 'bg-[var(--aqua)]',
  };

  return (
    <div className={`w-full ${className}`}>
      <div className="h-3 bg-[var(--charcoal)] rounded-full overflow-hidden">
        <div
          className={`h-full ${colorStyles[color]} transition-all duration-500 rounded-full`}
          style={{ width: `${percentage}%` }}
        />
      </div>
      {showLabel && (
        <div className="flex justify-between mt-1 text-sm">
          <span className="text-[var(--text-secondary)] font-mono">
            {value.toLocaleString()} / {max.toLocaleString()} USDT
          </span>
          <span className="text-[var(--gold)] font-mono">
            {percentage.toFixed(1)}%
          </span>
        </div>
      )}
    </div>
  );
}
