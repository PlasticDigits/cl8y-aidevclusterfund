import { useAccount, useConnect, useDisconnect, useBalance, useSwitchChain } from 'wagmi';
import { formatUnits } from 'viem';
import { Button } from '@/components/ui/Button';
import { EXPECTED_CHAIN_ID, EXPECTED_CHAIN_NAME, IS_TEST_MODE } from '@/lib/config';

export function WalletConnect() {
  const { address, isConnected, chainId } = useAccount();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: isSwitching } = useSwitchChain();
  
  // Read balance from the expected chain
  const { data: balance, isLoading: balanceLoading } = useBalance({ 
    address,
    chainId: EXPECTED_CHAIN_ID,
  });

  const isWrongChain = chainId !== undefined && chainId !== EXPECTED_CHAIN_ID;

  if (isConnected && address) {
    const shortAddress = `${address.slice(0, 6)}...${address.slice(-4)}`;
    
    // Format balance from wei to ETH
    const ethBalance = balance?.value !== undefined
      ? parseFloat(formatUnits(balance.value, balance.decimals)).toFixed(4)
      : balanceLoading ? '...' : '?';

    return (
      <div className="flex items-center gap-3">
        {isWrongChain && (
          <button
            onClick={() => switchChain({ chainId: EXPECTED_CHAIN_ID })}
            disabled={isSwitching}
            className="text-xs text-[var(--ember)] px-2 py-1 bg-[var(--ember)]/10 rounded border border-[var(--ember)]/30 hover:bg-[var(--ember)]/20 transition-colors"
          >
            {isSwitching ? 'Switching...' : `Switch to ${EXPECTED_CHAIN_NAME}`}
          </button>
        )}
        <div className="px-3 py-1.5 bg-[var(--midnight)] rounded-lg border border-[var(--charcoal)] flex items-center gap-2">
          <span className="font-mono text-sm text-[var(--aqua)]">
            {ethBalance} ETH
          </span>
          <span className="text-[var(--charcoal)]">|</span>
          <span className="font-mono text-sm text-[var(--text-primary)]">
            {shortAddress}
          </span>
        </div>
        <Button variant="outline" size="sm" onClick={() => disconnect()}>
          Disconnect
        </Button>
      </div>
    );
  }

  // Separate connector types
  const injectedWallets = connectors.filter(c => c.type === 'injected');
  const mockConnector = connectors.find(c => c.type === 'mock');
  const walletConnectConnector = connectors.find(c => c.type === 'walletConnect');

  return (
    <div className="flex gap-2 items-center">
      {/* EIP-6963 discovered wallets - privacy respecting */}
      {injectedWallets.map((connector) => (
        <Button
          key={connector.uid}
          variant="primary"
          size="sm"
          onClick={() => connect({ connector })}
          isLoading={isPending}
        >
          {connector.name === 'Injected' ? 'Connect Wallet' : connector.name}
        </Button>
      ))}
      
      {/* Mock wallet - test mode only, for quick testing with Anvil account */}
      {IS_TEST_MODE && mockConnector && (
        <Button
          variant="secondary"
          size="sm"
          onClick={() => connect({ connector: mockConnector })}
          isLoading={isPending}
          title="Use Anvil test account (0xf39F...)"
        >
          Mock Wallet
        </Button>
      )}
      
      {/* WalletConnect as separate option with warning */}
      {walletConnectConnector && (
        <Button
          variant="outline"
          size="sm"
          onClick={() => connect({ connector: walletConnectConnector })}
          isLoading={isPending}
          title="WalletConnect (Note: collects user data)"
        >
          WalletConnect
        </Button>
      )}
    </div>
  );
}
