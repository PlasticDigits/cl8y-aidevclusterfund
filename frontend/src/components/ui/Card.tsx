import { type ReactNode } from 'react';

interface Props {
  children: ReactNode;
  className?: string;
  variant?: 'default' | 'premium';
}

export function Card({ children, className = '', variant = 'default' }: Props) {
  const baseStyles = variant === 'premium' ? 'card-premium' : 'card';

  return (
    <div className={`${baseStyles} ${className}`}>
      {children}
    </div>
  );
}

interface CardHeaderProps {
  children: ReactNode;
  className?: string;
}

export function CardHeader({ children, className = '' }: CardHeaderProps) {
  return (
    <div className={`mb-4 ${className}`}>
      {children}
    </div>
  );
}

interface CardTitleProps {
  children: ReactNode;
  className?: string;
}

export function CardTitle({ children, className = '' }: CardTitleProps) {
  return (
    <h3 className={`text-xl font-bold font-display text-[var(--text-primary)] ${className}`}>
      {children}
    </h3>
  );
}

interface CardContentProps {
  children: ReactNode;
  className?: string;
}

export function CardContent({ children, className = '' }: CardContentProps) {
  return (
    <div className={className}>
      {children}
    </div>
  );
}
