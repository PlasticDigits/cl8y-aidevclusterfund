import { useState, useEffect } from 'react';
import { INVITE_CODE_STORAGE_KEY } from '@/lib/config';

export function useAccessCode() {
  const [hasAccess, setHasAccess] = useState<boolean | null>(null);

  useEffect(() => {
    const stored = localStorage.getItem(INVITE_CODE_STORAGE_KEY);
    setHasAccess(stored === 'true');
  }, []);

  const revokeAccess = () => {
    localStorage.removeItem(INVITE_CODE_STORAGE_KEY);
    setHasAccess(false);
  };

  return { hasAccess, revokeAccess };
}
