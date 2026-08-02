import assert from "node:assert/strict";
import test from "node:test";

import { isAutomatedBrowser } from "./browser_environment.mjs";

test("detects automated browsers from webdriver and user agent signals", () => {
  assert.equal(isAutomatedBrowser({ webdriver: true, userAgent: "Chrome" }), true);
  assert.equal(isAutomatedBrowser({ webdriver: false, userAgent: "HeadlessChrome/150" }), true);
  assert.equal(isAutomatedBrowser({ webdriver: false, userAgent: "HeadlessChromium/150" }), true);
  assert.equal(isAutomatedBrowser({ webdriver: false, userAgent: "Lighthouse" }), true);
});

test("detects automated browsers from client hint brands", () => {
  assert.equal(
    isAutomatedBrowser({
      webdriver: false,
      userAgent: "Chrome",
      userAgentData: { brands: [{ brand: "HeadlessChrome" }] },
    }),
    true
  );
});

test("allows normal browsers to connect", () => {
  assert.equal(isAutomatedBrowser({ webdriver: false, userAgent: "Mozilla Chrome/150" }), false);
});
