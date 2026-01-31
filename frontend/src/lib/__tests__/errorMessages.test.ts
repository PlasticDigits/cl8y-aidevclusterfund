import { describe, it, expect } from 'vitest';
import { parseContractError, errorMessages } from '../errorMessages';

describe('errorMessages', () => {
  describe('parseContractError', () => {
    it('returns friendly message for known error codes', () => {
      expect(parseContractError(new Error('BelowMinimumDeposit'))).toBe(
        'Deposit must be at least 100 USDT'
      );
      expect(parseContractError(new Error('TrancheFull'))).toBe(
        'This tranche is full. Wait for the next one.'
      );
      expect(parseContractError(new Error('NoteFullyRepaid'))).toBe(
        'This note has already been fully repaid.'
      );
    });

    it('handles user rejection', () => {
      expect(parseContractError(new Error('User rejected the request'))).toBe(
        'Transaction was rejected.'
      );
      expect(parseContractError(new Error('user rejected transaction'))).toBe(
        'Transaction was rejected.'
      );
    });

    it('returns fallback for unknown errors', () => {
      expect(parseContractError(new Error('Unknown error xyz'))).toBe(
        'Transaction failed. Please try again.'
      );
    });

    it('handles string errors', () => {
      expect(parseContractError('BelowMinimumDeposit')).toBe(
        'Deposit must be at least 100 USDT'
      );
    });

    it('extracts reverted reason strings', () => {
      const error = new Error("reverted with reason string 'Custom error message'");
      expect(parseContractError(error)).toBe('Custom error message');
    });
  });

  describe('errorMessages mapping', () => {
    it('has all expected error codes', () => {
      expect(errorMessages.BelowMinimumDeposit).toBeDefined();
      expect(errorMessages.TrancheNotActive).toBeDefined();
      expect(errorMessages.TrancheFull).toBeDefined();
      expect(errorMessages.NoteFullyRepaid).toBeDefined();
      expect(errorMessages.ZeroAmount).toBeDefined();
    });
  });
});
