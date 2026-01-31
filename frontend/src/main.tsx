import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { Toaster } from 'sonner';
import { WagmiProvider } from '@/providers/WagmiProvider';
import App from './App';
import './index.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <WagmiProvider>
      <App />
      <Toaster 
        theme="dark" 
        position="top-right"
        toastOptions={{
          style: {
            background: 'var(--charcoal)',
            border: '1px solid var(--obsidian)',
            color: 'var(--text-primary)',
          },
        }}
      />
    </WagmiProvider>
  </StrictMode>
);
