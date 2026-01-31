import { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { isAddress } from 'viem';
import { toast } from 'sonner';
import { ADDRESSES } from '@/lib/config';
import { DonationTrancheABI } from '@/lib/abi/DonationTranche';
import { parseContractError } from '@/lib/errorMessages';

interface TransferModalProps {
  isOpen: boolean;
  onClose: () => void;
  tokenId: bigint;
  onSuccess?: () => void;
}

export function TransferModal({ isOpen, onClose, tokenId, onSuccess }: TransferModalProps) {
  const { address } = useAccount();
  const [recipient, setRecipient] = useState('');

  const trancheAddress = ADDRESSES.DONATION_TRANCHE;

  // Validate address - derived state using useMemo
  const isValidAddress = useMemo(() => {
    return recipient !== '' && isAddress(recipient) && recipient.toLowerCase() !== address?.toLowerCase();
  }, [recipient, address]);

  // Write contract hook for transfer
  const { 
    writeContract, 
    data: txHash, 
    isPending: isWritePending,
    error: writeError,
    reset: resetWrite 
  } = useWriteContract();

  // Wait for transaction receipt
  const { 
    isLoading: isConfirming, 
    isSuccess: isConfirmed,
    error: confirmError 
  } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  // Handle write error
  useEffect(() => {
    if (writeError) {
      toast.error('Transfer failed', {
        description: parseContractError(writeError),
      });
    }
  }, [writeError]);

  // Handle confirmation error
  useEffect(() => {
    if (confirmError) {
      toast.error('Transaction failed', {
        description: parseContractError(confirmError),
      });
    }
  }, [confirmError]);

  // Define handleClose with useCallback before using it
  const handleClose = useCallback(() => {
    setRecipient('');
    resetWrite();
    onClose();
  }, [resetWrite, onClose]);

  // Track previous confirmed state
  const prevIsConfirmed = useRef(false);

  // Handle successful transfer with stable callback
  const handleTransferSuccess = useCallback(() => {
    toast.success('Note transferred successfully!', {
      description: `Note #${tokenId.toString()} sent to ${recipient.slice(0, 6)}...${recipient.slice(-4)}`,
    });
    onSuccess?.();
    handleClose();
  }, [tokenId, recipient, onSuccess, handleClose]);

  useEffect(() => {
    if (isConfirmed && !prevIsConfirmed.current) {
      queueMicrotask(handleTransferSuccess);
    }
    prevIsConfirmed.current = isConfirmed;
  }, [isConfirmed, handleTransferSuccess]);

  const handleTransfer = () => {
    if (!address || !trancheAddress || !isValidAddress) return;

    writeContract({
      address: trancheAddress,
      abi: DonationTrancheABI,
      functionName: 'safeTransferFrom',
      args: [address, recipient as `0x${string}`, tokenId],
    });
  };

  if (!isOpen) return null;

  const isLoading = isWritePending || isConfirming;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/70 backdrop-blur-sm"
        onClick={!isLoading ? handleClose : undefined}
      />

      {/* Modal */}
      <div className="relative z-10 w-full max-w-md mx-4 bg-[var(--obsidian)] border border-[var(--charcoal)] rounded-xl p-6 shadow-2xl">
        <h2 className="text-xl font-bold text-[var(--text-primary)] mb-2">
          Transfer Note #{tokenId.toString()}
        </h2>
        <p className="text-sm text-[var(--text-muted)] mb-6">
          Transfer this donation note NFT to another address
        </p>

        {/* Recipient Input */}
        <div className="mb-6">
          <label className="block text-sm text-[var(--text-secondary)] mb-2">
            Recipient Address
          </label>
          <input
            type="text"
            placeholder="0x..."
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            disabled={isLoading}
            className={`
              w-full px-4 py-3 rounded-lg 
              bg-[var(--charcoal)] border 
              text-[var(--text-primary)] placeholder:text-[var(--text-muted)]
              focus:outline-none focus:ring-2 focus:ring-[var(--gold)]/50
              disabled:opacity-50
              ${recipient && !isValidAddress 
                ? 'border-red-500' 
                : 'border-[var(--charcoal)]'}
            `}
          />
          {recipient && !isValidAddress && (
            <p className="text-red-400 text-xs mt-2">
              {!isAddress(recipient) 
                ? 'Please enter a valid Ethereum address'
                : 'Cannot transfer to yourself'}
            </p>
          )}
        </div>

        {/* Warning */}
        <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-4 mb-6">
          <p className="text-yellow-300 text-sm">
            <span className="font-semibold">Warning:</span> This action cannot be undone. 
            The note and its future rewards will belong to the recipient.
          </p>
        </div>

        {/* Actions */}
        <div className="flex gap-3">
          <button
            onClick={handleClose}
            disabled={isLoading}
            className="flex-1 px-4 py-3 rounded-lg border border-[var(--charcoal)] text-[var(--text-secondary)] hover:bg-[var(--charcoal)] transition-colors disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            onClick={handleTransfer}
            disabled={!isValidAddress || isLoading}
            className="flex-1 px-4 py-3 rounded-lg bg-[var(--gold)] text-[var(--black)] font-semibold hover:bg-[var(--gold)]/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isWritePending ? 'Confirm in Wallet...' 
              : isConfirming ? 'Transferring...' 
              : 'Transfer'}
          </button>
        </div>
      </div>
    </div>
  );
}
