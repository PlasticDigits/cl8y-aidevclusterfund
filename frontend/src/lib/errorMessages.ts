/**
 * User-friendly error messages for smart contract errors
 */
export const errorMessages: Record<string, string> = {
  'BelowMinimumDeposit': 'Deposit must be at least 100 USDT',
  'TrancheNotActive': 'No active tranche. Check back later.',
  'TrancheFull': 'This tranche is full. Wait for the next one.',
  'NoteFullyRepaid': 'This note has already been fully repaid.',
  'ZeroAmount': 'Amount must be greater than 0.',
  'ERC20InsufficientAllowance': 'Please approve USDT first.',
  'InsufficientBalance': 'Insufficient USDT balance.',
  'TrancheNonexistant': 'This tranche does not exist.',
  'NotOwner': 'You do not own this note.',
  'TransferToZeroAddress': 'Cannot transfer to zero address.',
  'user rejected': 'Transaction was rejected.',
  'User rejected': 'Transaction was rejected.',
  'insufficient funds': 'Insufficient funds for transaction.',
};

/**
 * Parse a contract error and return a user-friendly message
 */
export function parseContractError(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  
  for (const [key, friendly] of Object.entries(errorMessages)) {
    if (message.toLowerCase().includes(key.toLowerCase())) {
      return friendly;
    }
  }
  
  // Fallback: try to extract a readable message
  const revertMatch = message.match(/reverted with reason string '([^']+)'/);
  if (revertMatch) {
    return revertMatch[1];
  }
  
  return 'Transaction failed. Please try again.';
}
