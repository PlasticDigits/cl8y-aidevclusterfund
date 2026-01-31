import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration for E2E testing
 * 
 * Prerequisites:
 * 1. Start devnet: ./scripts/devnet-start.sh
 * 2. Devnet starts Vite dev server automatically at http://localhost:5173
 * 
 * Run tests:
 * - npm run test:e2e
 * - npx playwright test
 * - npx playwright test --ui (interactive mode)
 */
export default defineConfig({
  testDir: './e2e',
  
  // Run tests in parallel
  fullyParallel: true,
  
  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,
  
  // Retry on CI only
  retries: process.env.CI ? 2 : 0,
  
  // Opt out of parallel tests on CI
  workers: process.env.CI ? 1 : undefined,
  
  // Reporter to use
  reporter: 'html',
  
  // Shared settings for all tests
  use: {
    // Base URL to use in tests
    baseURL: 'http://localhost:5173',
    
    // Collect trace when retrying the failed test
    trace: 'on-first-retry',
    
    // Screenshot on failure
    screenshot: 'only-on-failure',
    
    // Timeout for each action
    actionTimeout: 30000,
  },

  // Configure projects for major browsers
  projects: [
    {
      name: 'desktop',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'mobile',
      use: { viewport: { width: 375, height: 667 } },
    },
  ],

  // Run local dev server before starting the tests
  // Note: Devnet script already starts Vite, so this is optional
  // Uncomment if running tests without devnet-start.sh
  // webServer: {
  //   command: 'npm run dev',
  //   url: 'http://localhost:5173',
  //   reuseExistingServer: !process.env.CI,
  // },
  
  // Global timeout for each test
  timeout: 60000,
  
  // Expect timeout
  expect: {
    timeout: 10000,
  },
});
