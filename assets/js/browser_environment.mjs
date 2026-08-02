const AUTOMATED_BROWSER_MARKERS = ["HeadlessChrome", "HeadlessChromium", "Lighthouse"];

export function isAutomatedBrowser(navigatorRef = globalThis.navigator) {
  if (!navigatorRef) {
    return false;
  }

  const userAgent = navigatorRef.userAgent || "";
  const brands = Array.isArray(navigatorRef.userAgentData?.brands)
    ? navigatorRef.userAgentData.brands.map(({ brand }) => brand || "")
    : [];

  return Boolean(navigatorRef.webdriver) ||
    AUTOMATED_BROWSER_MARKERS.some((marker) =>
      userAgent.includes(marker) || brands.some((brand) => brand.includes(marker))
    );
}
