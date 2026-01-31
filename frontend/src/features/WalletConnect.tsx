import { useAccount, useConnect, useDisconnect } from 'wagmi';
import { Button } from '@/components/ui/Button';

export function WalletConnect() {
  const { address, isConnected } = useAccount();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();

  if (isConnected && address) {
    const shortAddress = `${address.slice(0, 6)}...${address.slice(-4)}`;

    return (
      <div className="flex items-center gap-3">
        <div className="px-3 py-1.5 bg-[var(--midnight)] rounded-lg border border-[var(--charcoal)]">
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

  return (
    <div className="flex gap-2">
      {connectors.map((connector) => (
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
    </div>
  );
}
