import { createConfig, http } from 'wagmi';
import { bsc } from 'wagmi/chains';
import { injected, walletConnect } from 'wagmi/connectors';

const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID as string | undefined;

/**
 * Production wagmi config
 * 
 * Uses EIP-6963 for wallet discovery (privacy-respecting, no data collection).
 * WalletConnect is offered as a separate explicit option for users who need it
 * (e.g., mobile wallets, hardware wallets via mobile apps).
 * 
 * Note: WalletConnect collects and sells user data. Only use if necessary.
 */
export const wagmiConfig = createConfig({
  chains: [bsc],
  connectors: [
    // EIP-6963: discovers all browser extension wallets automatically
    // Each wallet (MetaMask, SafePal, Rabby, etc.) appears as separate option
    injected({
      shimDisconnect: true,
    }),
    // WalletConnect: optional, for mobile/remote wallets only
    // Only included if project ID is configured
    ...(projectId ? [walletConnect({ 
      projectId,
      showQrModal: true,
      metadata: {
        name: 'CL8Y Fund',
        description: 'Donate to CL8Y AI infrastructure',
        url: 'https://fund.cl8y.com',
        icons: ['https://fund.cl8y.com/favicon.svg'],
      },
    })] : []),
  ],
  transports: {
    [bsc.id]: http(import.meta.env.VITE_BSC_RPC_URL || 'https://bsc-dataseed.binance.org'),
  },
  ssr: false,
  // Enable EIP-6963 multi-injected provider discovery
  multiInjectedProviderDiscovery: true,
});
