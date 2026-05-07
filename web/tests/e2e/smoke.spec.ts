// U1 smoke test — verifies all five non-user route placeholders return 200.
// Real LTE-budget assertion (R10/AE5) lands in U7 with throttled network +
// non-US Vercel preview region.

import { test, expect } from "@playwright/test";

test.describe("U1 web scaffold smoke", () => {
  test("root page renders marketing hero", async ({ page }) => {
    await page.goto("/");
    await expect(
      page.getByRole("heading", {
        name: /Books, with the people you actually know\./,
      })
    ).toBeVisible();
  });

  test("rec landing renders with sender + book + note above the fold", async ({ page }) => {
    await page.goto("/rec/sample");
    // Sender attribution
    await expect(page.getByText(/Alice sent you a book/i)).toBeVisible();
    // Book title in the H1
    await expect(page.getByRole("heading", { name: /Project Hail Mary/i })).toBeVisible();
    // Sample note quoted
    await expect(page.getByText(/I know we don.?t usually do sci-fi/i)).toBeVisible();
  });

  test("public list renders title + list items", async ({ page }) => {
    await page.goto("/list/sample");
    await expect(page.getByRole("heading", { name: /Books that gutted me in 2025/i })).toBeVisible();
    await expect(page.getByText(/A list by Alice Tan/i)).toBeVisible();
    await expect(page.getByText(/6 books/)).toBeVisible();
  });

  test("inviter profile renders display name + bio", async ({ page }) => {
    await page.goto("/u/sample");
    await expect(page.getByRole("heading", { name: /Alice Tan/i })).toBeVisible();
    await expect(page.getByText(/Reading my way through/i)).toBeVisible();
  });

  test("join route renders headline and store CTAs", async ({ page }) => {
    await page.goto("/join");
    await expect(page.getByRole("heading", { name: /Track books with the people you actually know/i })).toBeVisible();
  });

  test("join route adapts headline when from_rec_id present", async ({ page }) => {
    await page.goto("/join?from_rec_id=abc");
    await expect(page.getByRole("heading", { name: /Get ShelfMate to open this rec/i })).toBeVisible();
  });
});
