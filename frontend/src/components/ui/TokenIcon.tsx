interface TokenIconProps {
  token: 'USDT' | 'CL8Y' | 'CZODIAC';
  size?: 'xs' | 'sm' | 'md' | 'lg';
  className?: string;
}

const TOKEN_IMAGES = {
  USDT: '/images/0x55d398326f99059fF775485246999027B3197955.svg',
  CL8Y: '/images/CLAY-64.png',
  CZODIAC: '/images/czodiac-logo.png',
} as const;

const SIZES = {
  xs: 'w-3 h-3',
  sm: 'w-4 h-4',
  md: 'w-6 h-6',
  lg: 'w-8 h-8',
} as const;

export function TokenIcon({ token, size = 'md', className = '' }: TokenIconProps) {
  return (
    <img
      src={TOKEN_IMAGES[token]}
      alt={token}
      className={`${SIZES[size]} inline-block ${className}`}
    />
  );
}

// Convenience wrapper for token amount display
interface TokenAmountProps {
  amount: string | number;
  token: 'USDT' | 'CL8Y';
  size?: 'xs' | 'sm' | 'md' | 'lg';
  className?: string;
  iconPosition?: 'left' | 'right';
}

export function TokenAmount({ 
  amount, 
  token, 
  size = 'md', 
  className = '',
  iconPosition = 'right'
}: TokenAmountProps) {
  const icon = <TokenIcon token={token} size={size} />;
  
  return (
    <span className={`inline-flex items-center gap-1.5 ${className}`}>
      {iconPosition === 'left' && icon}
      <span>{amount}</span>
      {iconPosition === 'right' && icon}
    </span>
  );
}
