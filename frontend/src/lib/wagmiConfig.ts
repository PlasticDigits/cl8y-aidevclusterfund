import { createConfig, http } from 'wagmi';
import { bsc } from 'wagmi/chains';
import { injected, walletConnect } from 'wagmi/connectors';

const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID;

const connectors = projectId
  ? [injected(), walletConnect({ projectId })]
  : [injected()];

export const wagmiConfig = createConfig({
  chains: [bsc],
  connectors,
  transports: {
    [bsc.id]: http(import.meta.env.VITE_BSC_RPC_URL || 'https://bsc-dataseed.binance.org'),
  },
  ssr: false,
});
