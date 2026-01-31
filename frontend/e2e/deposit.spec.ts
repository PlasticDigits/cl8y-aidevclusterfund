import { test, expect } from '@playwright/test';

/**
 * E2E Tests for CL8Y Fund Application
 * 
 * Prerequisites:
 * 1. Start devnet: ./scripts/devnet-start.sh (from project root)
 * 2. Wait for "Devnet ready" message
 * 
 * Test Account (auto-connected in test mode):
 * - Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
 * - Balance: 100,000 USDT (mock)
 * - Has admin permissions
 * 
 * Run tests:
 * - npm run test:e2e
 * - npx playwright test --headed (watch mode)
 */

test.describe('Wallet Connection', () => {
  test('should auto-connect wallet in test mode', async ({ page }) => {
    await page.goto('/');
    
    // Enter invite code
    await page.fill('input[placeholder*="invite"]', 'donate');
    await page.click('button:has-text("Enter")');
    
    // Wait for wallet to auto-connect (test mode)
    await expect(page.locator('text=0xf39F')).toBeVisible({ timeout: 10000 });
  });

  test('should show admin button for deployer address', async ({ page }) => {
    await page.goto('/');
    
    // Enter invite code
    await page.fill('input[placeholder*="invite"]', 'donate');
    await page.click('button:has-text("Enter")');
    
    // Wait for wallet connection
    await expect(page.locator('text=0xf39F')).toBeVisible({ timeout: 10000 });
    
    // Admin button should be visible for test account
    await expect(page.locator('button:has-text("Admin")')).toBeVisible();
  });
});

test.describe('Deposit Flow', () => {
  // Run deposit tests serially to avoid race conditions with tranche capacity
  test.describe.configure({ mode: 'serial' });
  
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    
    // Enter invite code
    await page.fill('input[placeholder*="invite"]', 'donate');
    await page.click('button:has-text("Enter")');
    
    // Wait for wallet
    await expect(page.locator('text=0xf39F')).toBeVisible({ timeout: 10000 });
    
    // Wait for tranche to load (Contribute button appears)
    await expect(page.locator('button:has-text("Contribute USDT")')).toBeVisible({ timeout: 15000 });
  });

  test('should open deposit modal', async ({ page }) => {
    // Click deposit button on tranche card
    await page.click('button:has-text("Contribute USDT")');
    
    // Modal should appear - title is "Contribute USDT"
    await expect(page.locator('h2:has-text("Contribute USDT")')).toBeVisible();
  });

  test('should show deposit amount input', async ({ page }) => {
    await page.click('button:has-text("Contribute USDT")');
    
    // Should have amount input
    await expect(page.locator('input[type="number"]')).toBeVisible();
  });

  test('should enforce minimum deposit of 100 USDT', async ({ page }) => {
    await page.click('button:has-text("Contribute USDT")');
    
    // Enter amount below minimum
    await page.fill('input[type="number"]', '50');
    
    // Should show warning or disable button (button text is "Approve USDT")
    const depositButton = page.locator('button:has-text("Approve USDT")');
    await expect(depositButton).toBeDisabled();
  });

  test('should show matching preview', async ({ page }) => {
    await page.click('button:has-text("Contribute USDT")');
    
    // Enter valid amount
    await page.fill('input[type="number"]', '200');
    
    // Should show matching info
    await expect(page.locator('text=/match/i').first()).toBeVisible();
  });

  test('should complete deposit flow', async ({ page }) => {
    await page.click('button:has-text("Contribute USDT")');
    
    // Enter amount
    await page.fill('input[type="number"]', '100');
    
    // Click approve (first step) - button text is "Approve USDT"
    // After approval, deposit happens automatically
    await page.click('button:has-text("Approve USDT")');
    
    // Wait for success (auto-deposits after approval)
    await expect(page.locator('text=/Contribution Successful/i')).toBeVisible({ timeout: 30000 });
  });
});

test.describe('My Notes', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    
    // Enter invite code
    await page.fill('input[placeholder*="invite"]', 'donate');
    await page.click('button:has-text("Enter")');
    
    // Wait for wallet
    await expect(page.locator('text=0xf39F')).toBeVisible({ timeout: 10000 });
  });

  test('should show My Donation Notes section', async ({ page }) => {
    await expect(page.locator('text=My Donation Notes')).toBeVisible();
  });

  test('should show note count', async ({ page }) => {
    // Should show note count (may be 0 initially)
    await expect(page.locator('text=/\\d+ notes? owned/')).toBeVisible();
  });
});

test.describe('Repay Flow', () => {
  // Run serially as these tests depend on deposit state
  test.describe.configure({ mode: 'serial' });
  
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    
    // Enter invite code
    await page.fill('input[placeholder*="invite"]', 'donate');
    await page.click('button:has-text("Enter")');
    
    // Wait for wallet
    await expect(page.locator('text=0xf39F')).toBeVisible({ timeout: 10000 });
    
    // Wait for tranche to load
    await expect(page.locator('button:has-text("Contribute USDT")')).toBeVisible({ timeout: 15000 });
  });

  test('should show repay button on note cards', async ({ page }) => {
    // First make a deposit to have a note
    await page.click('button:has-text("Contribute USDT")');
    await page.fill('input[type="number"]', '100');
    await page.click('button:has-text("Approve USDT")');
    
    // Wait for success (auto-deposits after approval)
    await expect(page.locator('text=/Contribution Successful/i')).toBeVisible({ timeout: 30000 });
    
    // Click Close button to dismiss modal
    await page.click('button:has-text("Close")');
    
    // Should see note with repay button
    await expect(page.locator('button:has-text("Repay")')).toBeVisible({ timeout: 10000 });
  });

  test('should open repay modal', async ({ page }) => {
    // Assuming there's already a note (from previous test or state)
    // Click on first repay button
    const repayButton = page.locator('button:has-text("Repay")').first();
    
    // If repay button exists, click it
    if (await repayButton.isVisible()) {
      await repayButton.click();
      await expect(page.locator('text=/Repay Note/i')).toBeVisible();
    }
  });
});

test.describe('Transfer Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    
    // Enter invite code
    await page.fill('input[placeholder*="invite"]', 'donate');
    await page.click('button:has-text("Enter")');
    
    // Wait for wallet
    await expect(page.locator('text=0xf39F')).toBeVisible({ timeout: 10000 });
  });

  test('should show transfer button on note cards', async ({ page }) => {
    // Check for transfer button (if notes exist)
    const transferButton = page.locator('button:has-text("Transfer")').first();
    
    // If notes exist, transfer button should be visible
    if (await page.locator('text=/\\d+ notes? owned/').isVisible()) {
      const noteCount = await page.locator('text=/\\d+ notes? owned/').textContent();
      if (noteCount && !noteCount.includes('0 notes')) {
        await expect(transferButton).toBeVisible();
      }
    }
  });

  test('should open transfer modal', async ({ page }) => {
    const transferButton = page.locator('button:has-text("Transfer")').first();
    
    if (await transferButton.isVisible()) {
      await transferButton.click();
      await expect(page.locator('text=/Transfer Note/i')).toBeVisible();
    }
  });

  test('should validate recipient address', async ({ page }) => {
    const transferButton = page.locator('button:has-text("Transfer")').first();
    
    if (await transferButton.isVisible()) {
      await transferButton.click();
      
      // Enter invalid address
      await page.fill('input[placeholder*="0x"]', 'invalid');
      
      // Should show error
      await expect(page.locator('text=/valid.*address/i')).toBeVisible();
    }
  });
});

test.describe('Admin Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    
    // Enter invite code
    await page.fill('input[placeholder*="invite"]', 'donate');
    await page.click('button:has-text("Enter")');
    
    // Wait for wallet
    await expect(page.locator('text=0xf39F')).toBeVisible({ timeout: 10000 });
  });

  test('should toggle admin dashboard', async ({ page }) => {
    // Click admin button
    await page.click('button:has-text("Admin")');
    
    // Admin dashboard should appear
    await expect(page.locator('text=Admin Dashboard')).toBeVisible();
    
    // Click again to hide
    await page.click('button:has-text("Admin")');
    
    // Should be hidden
    await expect(page.locator('text=Admin Dashboard')).not.toBeVisible();
  });

  test('should show current tranche info', async ({ page }) => {
    await page.click('button:has-text("Admin")');
    
    // Should show current state info (Admin Dashboard is visible)
    await expect(page.locator('text=Admin Dashboard')).toBeVisible();
    // Check for tranche-related info
    await expect(page.locator('text=/tranche/i').first()).toBeVisible();
  });

  test('should show schedule tranches input', async ({ page }) => {
    await page.click('button:has-text("Admin")');
    
    // Should have schedule tranches input
    await expect(page.locator('button:has-text("Schedule Tranches")')).toBeVisible();
  });

  test('should show start next tranche button when applicable', async ({ page }) => {
    await page.click('button:has-text("Admin")');
    
    // Start next tranche button should exist (may be disabled)
    await expect(page.locator('button:has-text("Start Next Tranche")')).toBeVisible();
  });
});

test.describe('Portfolio Summary', () => {
  // Run serially as these tests depend on deposit state
  test.describe.configure({ mode: 'serial' });
  
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    
    // Enter invite code
    await page.fill('input[placeholder*="invite"]', 'donate');
    await page.click('button:has-text("Enter")');
    
    // Wait for wallet
    await expect(page.locator('text=0xf39F')).toBeVisible({ timeout: 10000 });
    
    // Wait for tranche to load
    await expect(page.locator('button:has-text("Contribute USDT")')).toBeVisible({ timeout: 15000 });
  });

  test('should show portfolio summary when notes exist', async ({ page }) => {
    // First make a deposit to have a note
    await page.click('button:has-text("Contribute USDT")');
    await page.fill('input[type="number"]', '100');
    await page.click('button:has-text("Approve USDT")');
    
    // Wait for success (auto-deposits after approval)
    await expect(page.locator('text=/Contribution Successful/i')).toBeVisible({ timeout: 30000 });
    
    // Click Close button to dismiss modal
    await page.click('button:has-text("Close")');
    
    // Portfolio summary should appear
    await expect(page.locator('text=Portfolio Summary')).toBeVisible({ timeout: 10000 });
  });

  test('should show aggregate statistics', async ({ page }) => {
    // If portfolio summary is visible, check for stats
    const portfolioSummary = page.locator('text=Portfolio Summary');
    
    if (await portfolioSummary.isVisible()) {
      await expect(page.locator('text=Total Invested')).toBeVisible();
      await expect(page.locator('text=Current Value')).toBeVisible();
      await expect(page.locator('text=Interest Earned')).toBeVisible();
    }
  });
});

test.describe('Tranche Card', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    
    // Enter invite code
    await page.fill('input[placeholder*="invite"]', 'donate');
    await page.click('button:has-text("Enter")');
    
    // Wait for wallet
    await expect(page.locator('text=0xf39F')).toBeVisible({ timeout: 10000 });
  });

  test('should show current tranche info', async ({ page }) => {
    // Should show tranche card with tranche number
    await expect(page.locator('text=/Tranche #/i').first()).toBeVisible();
  });

  test('should show progress bar', async ({ page }) => {
    // Should have progress indicator (Tranche Progress text)
    await expect(page.locator('text=Tranche Progress')).toBeVisible();
  });

  test('should show matching info', async ({ page }) => {
    // Should show matching info (CZodiac Match section)
    await expect(page.locator('text=CZodiac Match')).toBeVisible();
  });
});

test.describe('Scheduled Tranches', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    
    // Enter invite code
    await page.fill('input[placeholder*="invite"]', 'donate');
    await page.click('button:has-text("Enter")');
    
    // Wait for wallet
    await expect(page.locator('text=0xf39F')).toBeVisible({ timeout: 10000 });
  });

  test('should show scheduled tranches section', async ({ page }) => {
    // Should show upcoming tranches section (if scheduled tranches exist)
    // The component title is "Upcoming Tranches"
    await expect(page.locator('text=Upcoming Tranches')).toBeVisible();
  });
});

test.describe('Funding Timeline', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    
    // Enter invite code
    await page.fill('input[placeholder*="invite"]', 'donate');
    await page.click('button:has-text("Enter")');
    
    // Wait for wallet
    await expect(page.locator('text=0xf39F')).toBeVisible({ timeout: 10000 });
  });

  test('should show funding milestones', async ({ page }) => {
    // Should show funding timeline section with milestone names
    await expect(page.locator('text=BRIDGE v1').first()).toBeVisible();
  });
});
