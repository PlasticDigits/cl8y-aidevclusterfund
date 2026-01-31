import { useState, type ReactNode } from 'react';
import { INVITE_CODE, INVITE_CODE_STORAGE_KEY } from '@/lib/config';

interface Props {
  children: ReactNode;
}

export function AccessGate({ children }: Props) {
  const [hasAccess, setHasAccess] = useState<boolean>(() => {
    const stored = localStorage.getItem(INVITE_CODE_STORAGE_KEY);
    return stored === 'true';
  });
  const [inputCode, setInputCode] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (inputCode.toLowerCase().trim() === INVITE_CODE) {
      localStorage.setItem(INVITE_CODE_STORAGE_KEY, 'true');
      setHasAccess(true);
      setError('');
    } else {
      setError('Invalid invite code');
    }
  };

  // Unlocked - show app
  if (hasAccess) {
    return <>{children}</>;
  }

  // Locked - show gate
  return (
    <div className="min-h-screen bg-[var(--black)] flex items-center justify-center p-4">
      <div className="card-premium max-w-md w-full text-center">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-[var(--gold)] font-display mb-2">
            CL8Y Fund
          </h1>
          <p className="text-[var(--text-secondary)]">
            Private AI Infrastructure Fundraiser
          </p>
        </div>

        <div className="mb-6 p-4 bg-[var(--charcoal)] rounded-lg">
          <p className="text-sm text-[var(--text-muted)]">
            This is a private, invite-only fundraiser for the CL8Y community.
            Enter your invite code to continue.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <input
              type="text"
              value={inputCode}
              onChange={(e) => {
                setInputCode(e.target.value);
                setError('');
              }}
              placeholder="Enter invite code"
              className="w-full px-4 py-3 bg-[var(--midnight)] border border-[var(--charcoal)] rounded-lg text-[var(--text-primary)] placeholder-[var(--text-muted)] focus:outline-none focus:border-[var(--gold)] transition-colors"
              autoFocus
            />
            {error && (
              <p className="mt-2 text-sm text-[var(--magenta)]">{error}</p>
            )}
          </div>

          <button
            type="submit"
            className="w-full py-3 px-6 bg-gradient-to-r from-[var(--gold-dark)] to-[var(--gold)] text-[var(--black)] font-semibold rounded-lg hover:opacity-90 transition-opacity"
          >
            Enter
          </button>
        </form>

        <p className="mt-6 text-xs text-[var(--text-muted)]">
          All contributions are matched 1:1 by CZodiac
        </p>
      </div>
    </div>
  );
}
