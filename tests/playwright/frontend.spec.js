// tests/playwright/frontend.spec.js
import { test, expect } from '@playwright/test';

test.describe('Project Capacity Planning App', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000');
  });

  test('should load the dashboard with metrics', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('Project Capacity Planning');
    await expect(page.locator('text=Total Projects')).toBeVisible();
    await expect(page.locator('text=Total QA Resources')).toBeVisible();
  });

  test('should filter projects by status', async ({ page }) => {
    await page.selectOption('select', 'in development');
    await expect(page.locator('table tbody tr')).first().toBeVisible();
    const statusCells = await page.locator('table tbody tr td:nth-child(2)').allTextContents();
    for (const status of statusCells) {
      expect(status).toContain('in development');
    }
  });

  test('should search by assignee', async ({ page }) => {
    await page.fill('input[placeholder="Enter assignee name..."]', 'Alice');
    await page.waitForTimeout(500);
    const rows = await page.locator('table tbody tr').count();
    if (rows > 0) {
      const assignees = await page.locator('table tbody tr td:nth-child(3)').allTextContents();
      for (const assignee of assignees) {
        expect(assignee.toLowerCase()).toContain('alice');
      }
    }
  });

  test('should open upload modal and validate', async ({ page }) => {
    await page.click('text=Import from Sheet');
    await expect(page.locator('text=Import from Google Sheets')).toBeVisible();
    await page.click('text=Cancel');
    await expect(page.locator('text=Import from Google Sheets')).not.toBeVisible();
  });

  test('should export PDF', async ({ page }) => {
    const downloadPromise = page.waitForEvent('download');
    await page.click('text=Export PDF');
    const download = await downloadPromise;
    expect(download.suggestedFilename()).toContain('capacity-planning-report.pdf');
  });
});
