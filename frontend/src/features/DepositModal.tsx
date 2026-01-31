import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { toast } from 'sonner';
import { Button } from '@/components/ui/Button';
import { ADDRESSES } from '@/lib/config';
import { ERC20ABI } from '@/lib/abi/erc20';
import { DonationTrancheABI } from '@/lib/abi/DonationTranche';
import { parseContractError } from '@/lib/errorMessages';

interface Props {
  isOpen: boolean;
  onClose: () => void;
  remainingCapacity: bigint;
  onSuccess?: () => void;
}

export function DepositModal({ isOpen, onClose, remainingCapacity, onSuccess }: Props) {
  const [amount, setAmount] = useState('');
  const [step, setStep] = useState<'input' | 'approve' | 'deposit' | 'success'>('input');
  
  const { address } = useAccount();
  const trancheAddress = ADDRESSES.DONATION_TRANCHE;

  // Read USDT balance
  const { data: usdtBalance } = useReadContract({
    address: ADDRESSES.USDT,
    abi: ERC20ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  // Read USDT allowance
  const { data: allowance } = useReadContract({
    address: ADDRESSES.USDT,
    abi: ERC20ABI,
    functionName: 'allowance',
    args: address && trancheAddress ? [address, trancheAddress] : undefined,
    query: { enabled: !!address && !!trancheAddress },
  });

  // Read effective minimum deposit from contract
  const { data: effectiveMinDeposit } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'getEffectiveMinDeposit',
    query: { enabled: !!trancheAddress },
  });

  const amountWei = amount ? parseEther(amount) : 0n;

  // Read expected match for the current amount
  const { data: expectedMatch } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'getExpectedMatch',
    args: [amountWei],
    query: { enabled: !!trancheAddress && amountWei > 0n },
  });

  // Approve USDT
  const { writeContract: approve, data: approveTx, isPending: isApproving, error: approveError } = useWriteContract();
  const { isLoading: isApproveConfirming, isSuccess: isApproveSuccess } = useWaitForTransactionReceipt({
    hash: approveTx,
  });

  // Deposit
  const { writeContract: deposit, data: depositTx, isPending: isDepositing, error: depositError } = useWriteContract();
  const { isLoading: isDepositConfirming, isSuccess: isDepositSuccess } = useWaitForTransactionReceipt({
    hash: depositTx,
  });

  // Show toast on approve transaction submitted
  useEffect(() => {
    if (approveTx) {
      toast.loading('Approving USDT...', { id: 'approve' });
    }
  }, [approveTx]);

  // Show toast on approve success
  useEffect(() => {
    if (isApproveSuccess) {
      toast.success('USDT approved!', { id: 'approve' });
    }
  }, [isApproveSuccess]);

  // Show toast on approve error
  useEffect(() => {
    if (approveError) {
      toast.error(`Approval failed: ${parseContractError(approveError)}`, { id: 'approve' });
      setStep('input');
    }
  }, [approveError]);

  // Show toast on deposit transaction submitted
  useEffect(() => {
    if (depositTx) {
      toast.loading('Processing deposit...', { id: 'deposit' });
    }
  }, [depositTx]);

  // Show toast on deposit success
  useEffect(() => {
    if (isDepositSuccess) {
      toast.success('Deposit successful! Your donation note has been minted.', { id: 'deposit' });
    }
  }, [isDepositSuccess]);

  // Show toast on deposit error
  useEffect(() => {
    if (depositError) {
      toast.error(`Deposit failed: ${parseContractError(depositError)}`, { id: 'deposit' });
      setStep('input');
    }
  }, [depositError]);

  if (!isOpen) return null;

  const needsApproval = allowance !== undefined && amountWei > allowance;
  const maxAmount = remainingCapacity < (usdtBalance || 0n) ? remainingCapacity : (usdtBalance || 0n);
  
  // Get effective min deposit (fallback to 100 USDT if not loaded)
  const minDeposit = effectiveMinDeposit ?? parseEther('100');
  const minDepositFormatted = Number(formatEther(minDeposit)).toFixed(3);
  
  // Extract match data
  const matchAmount = expectedMatch ? expectedMatch[0] : 0n;
  const matchPercentBps = expectedMatch ? expectedMatch[1] : 0n;
  const matchPercent = Number(matchPercentBps) / 100; // Convert bps to percentage

  const handleApprove = () => {
    if (!trancheAddress) return;
    setStep('approve');
    approve({
      address: ADDRESSES.USDT,
      abi: ERC20ABI,
      functionName: 'approve',
      args: [trancheAddress, amountWei],
    });
  };

  const handleDeposit = () => {
    if (!trancheAddress) return;
    setStep('deposit');
    deposit({
      address: trancheAddress,
      abi: DonationTrancheABI,
      functionName: 'deposit',
      args: [amountWei],
    });
  };

  // Handle success
  if (isDepositSuccess && step === 'deposit') {
    setStep('success');
    onSuccess?.();
  }

  // Continue to deposit after approval
  if (isApproveSuccess && step === 'approve') {
    handleDeposit();
  }

  // Calculate the actual amount that will be deposited (contract accepts partial deposits)
  const actualDepositAmount = amountWei > remainingCapacity ? remainingCapacity : amountWei;
  const isPartialDeposit = amountWei > remainingCapacity && remainingCapacity > 0n;

  const isValidAmount =
    actualDepositAmount >= minDeposit &&
    amountWei <= (usdtBalance || 0n) &&
    remainingCapacity > 0n;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/80"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="relative bg-[var(--midnight)] border border-[var(--charcoal)] rounded-xl p-6 max-w-md w-full">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-[var(--text-muted)] hover:text-[var(--text-primary)]"
        >
          ✕
        </button>

        <h2 className="text-xl font-bold font-display text-[var(--gold)] mb-4">
          Contribute USDT
        </h2>

        {step === 'success' ? (
          <div className="text-center py-8">
            <div className="w-16 h-16 bg-[var(--aqua)] rounded-full flex items-center justify-center mx-auto mb-4">
              <span className="text-3xl">✓</span>
            </div>
            <h3 className="text-lg font-bold text-[var(--text-primary)] mb-2">
              Contribution Successful!
            </h3>
            <p className="text-[var(--text-secondary)] mb-4">
              Your donation note NFT has been minted.
            </p>
            <Button variant="primary" onClick={onClose}>
              Close
            </Button>
          </div>
        ) : (
          <>
            {/* Balance info */}
            <div className="mb-4 p-3 bg-[var(--charcoal)] rounded-lg">
              <div className="flex justify-between text-sm">
                <span className="text-[var(--text-muted)]">Your USDT Balance</span>
                <span className="font-mono text-[var(--text-primary)]">
                  {usdtBalance ? formatEther(usdtBalance) : '0'} USDT
                </span>
              </div>
              <div className="flex justify-between text-sm mt-1">
                <span className="text-[var(--text-muted)]">Available in Tranche</span>
                <span className="font-mono text-[var(--text-primary)]">
                  {formatEther(remainingCapacity)} USDT
                </span>
              </div>
            </div>

            {/* Tranche full warning */}
            {remainingCapacity === 0n && (
              <div className="mb-4 p-3 bg-red-500/10 border border-red-500/30 rounded-lg">
                <p className="text-sm text-red-400">
                  This tranche is full. Please wait for the next tranche to open.
                </p>
              </div>
            )}

            {/* Amount input */}
            <div className="mb-4">
              <label className="block text-sm text-[var(--text-secondary)] mb-2">
                Amount (min {minDepositFormatted} USDT)
              </label>
              <div className="relative">
                <input
                  type="number"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="0.00"
                  className="w-full px-4 py-3 bg-[var(--black)] border border-[var(--charcoal)] rounded-lg text-[var(--text-primary)] font-mono focus:outline-none focus:border-[var(--gold)]"
                  disabled={step !== 'input' || remainingCapacity === 0n}
                />
                <button
                  onClick={() => setAmount(formatEther(maxAmount))}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-[var(--gold)] hover:underline"
                  disabled={remainingCapacity === 0n}
                >
                  MAX
                </button>
              </div>
            </div>

            {/* Partial deposit warning */}
            {isPartialDeposit && (
              <div className="mb-4 p-3 bg-orange-500/10 border border-orange-500/30 rounded-lg">
                <p className="text-sm text-orange-400">
                  Only {formatEther(remainingCapacity)} USDT remaining in tranche.
                </p>
                <p className="text-sm text-[var(--text-secondary)] mt-1">
                  Your deposit will be capped to {formatEther(remainingCapacity)} USDT.
                </p>
              </div>
            )}

            {/* Matching info */}
            {actualDepositAmount > 0n && (
              <div className="mb-6 p-3 bg-[var(--gold)]/10 border border-[var(--gold)]/30 rounded-lg">
                <div className="flex justify-between items-center mb-2">
                  <span className="text-sm text-[var(--text-secondary)]">Your Deposit</span>
                  <span className="font-mono text-[var(--text-primary)]">
                    {formatEther(actualDepositAmount)} USDT
                  </span>
                </div>
                <div className="flex justify-between items-center mb-2">
                  <span className="text-sm text-[var(--text-secondary)]">CZodiac Matching</span>
                  <span className="font-mono text-[var(--gold)]">
                    +{formatEther(matchAmount)} USDT ({matchPercent.toFixed(0)}%)
                  </span>
                </div>
                {matchPercent < 100 && matchAmount > 0n && (
                  <p className="text-xs text-orange-400 mt-1">
                    Matching limited by {matchPercentBps < 10000n ? 'tranche capacity or vault funds' : 'vault funds'}
                  </p>
                )}
                {matchPercent === 0 && (
                  <p className="text-xs text-orange-400 mt-1">
                    No matching available (vault empty or tranche will be full)
                  </p>
                )}
                <div className="border-t border-[var(--gold)]/20 mt-2 pt-2">
                  <div className="flex justify-between items-center">
                    <span className="text-sm text-[var(--text-secondary)]">Total Impact</span>
                    <span className="font-mono text-[var(--gold)] font-bold">
                      {formatEther(actualDepositAmount + matchAmount)} USDT
                    </span>
                  </div>
                  <p className="text-xs text-[var(--gold)] mt-1">
                    + {(Number(formatEther(actualDepositAmount + matchAmount)) * 0.75).toFixed(2)} USD in QA/Audit services
                  </p>
                </div>
              </div>
            )}

            {/* Action buttons */}
            <div className="flex gap-3">
              <Button variant="secondary" onClick={onClose} className="flex-1">
                Cancel
              </Button>
              {needsApproval ? (
                <Button
                  variant="primary"
                  onClick={handleApprove}
                  isLoading={isApproving || isApproveConfirming}
                  disabled={!isValidAmount}
                  className="flex-1"
                >
                  Approve USDT
                </Button>
              ) : (
                <Button
                  variant="primary"
                  onClick={handleDeposit}
                  isLoading={isDepositing || isDepositConfirming}
                  disabled={!isValidAmount}
                  className="flex-1"
                >
                  Contribute
                </Button>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
