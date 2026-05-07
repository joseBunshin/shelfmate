// U1 smoke test — verifies all five non-user route placeholders return 200.
// Real LTE-budget assertion (R10/AE5) lands in U7 with throttled network +
// non-US Vercel preview region.

import { test, expect } from "@playwright/test";

test.describe("U1 web scaffold smoke", () => {
  test("root page renders ShelfMate heading", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("heading", { name: "ShelfMate" })).toBeVisible();
  });

  test("rec landing route renders with recId param", async ({ page }) => {
    await page.goto("/rec/test-rec-123");
    await expect(page.getByText(/recId = test-rec-123/)).toBeVisible();
  });

  test("profile route renders with userId param", async ({ page }) => {
    await page.goto("/u/test-user-456");
    await expect(page.getByText(/userId = test-user-456/)).toBeVisible();
  });

  test("public list route renders with listId param", async ({ page }) => {
    await page.goto("/list/test-list-789");
    await expect(page.getByText(/listId = test-list-789/)).toBeVisible();
  });

  test("join route renders with platform detection", async ({ page }) => {
    await page.goto("/join");
    await expect(page.getByText(/detected platform =/)).toBeVisible();
  });
});
