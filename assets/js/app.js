import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import ScrollSpy from "./hooks/scroll_spy";
import ScrollReveal from "./hooks/scroll_reveal";
import HashScrollLink from "./hooks/hash_scroll_link";
import ContentAssistantTurnstile from "./hooks/content_assistant_turnstile.mjs";
import EcosystemOrbit from "./hooks/ecosystem_orbit";
import { createPostHogManager, normalizePath } from "./posthog_manager.mjs";

const ANALYTICS_FLUSH_INTERVAL_MS = 1000;

function applyTheme(theme) {
  if (theme === "light") {
    document.documentElement.classList.add("light");
    document.documentElement.classList.remove("dark");
  } else {
    document.documentElement.classList.remove("light");
    document.documentElement.classList.add("dark");
  }

  localStorage.setItem("theme", theme);
}

function syncUtilityTopBarHeight() {
  const utilityBar = document.getElementById("logged-in-utility-bar");
  const height = utilityBar ? Math.ceil(utilityBar.getBoundingClientRect().height) : 0;

  document.documentElement.style.setProperty("--utility-top-bar-height", `${height}px`);
}

function parsePositiveInt(value) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : undefined;
}

const analyticsQueue = [];
let analyticsFlushTimer = null;

const postHogManager = createPostHogManager({
  windowRef: window,
  documentRef: document,
  importPostHog: () => import("posthog-js"),
  requestIdleCallbackFn: window.requestIdleCallback ? window.requestIdleCallback.bind(window) : null,
  cancelIdleCallbackFn: window.cancelIdleCallback ? window.cancelIdleCallback.bind(window) : null,
  setTimeoutFn: window.setTimeout.bind(window),
  clearTimeoutFn: window.clearTimeout.bind(window),
});

function flushAnalyticsQueue() {
  analyticsFlushTimer = null;

  while (analyticsQueue.length > 0) {
    const payload = analyticsQueue.shift();

    fetch("/analytics/events", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-csrf-token": csrfToken,
      },
      credentials: "same-origin",
      keepalive: true,
      body: JSON.stringify(payload),
    }).catch(() => {});
  }
}

function scheduleAnalyticsFlush() {
  if (analyticsFlushTimer === null) {
    analyticsFlushTimer = setTimeout(flushAnalyticsQueue, ANALYTICS_FLUSH_INTERVAL_MS);
  }
}

function trackAnalyticsEvent(eventName, properties = {}) {
  if (!eventName || typeof eventName !== "string") {
    return;
  }

  const payload = {
    event: eventName,
    properties: {
      ...properties,
      path: normalizePath(properties.path),
    },
  };

  analyticsQueue.push(payload);
  scheduleAnalyticsFlush();
  postHogManager.trackEvent(eventName, payload.properties);
}

window.__agentJidoTrackEvent = trackAnalyticsEvent;

let Hooks = {
  ScrollSpy,
  ScrollReveal,
  HashScrollLink,
  ContentAssistantTurnstile,
  EcosystemOrbit,
};

Hooks.ThemeToggle = {
  mounted() {
    this.updateButtonStates();
    this.handleClick = () => {
      const isLight = document.documentElement.classList.contains("light");
      const nextTheme = isLight ? "dark" : "light";

      applyTheme(nextTheme);
      this.updateButtonStates();
    };

    this.el.addEventListener("click", this.handleClick);
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleClick);
  },

  updateButtonStates() {
    const isLight = document.documentElement.classList.contains("light");
    const moonIcon = this.el.querySelector("[data-theme-icon='moon']");
    const sunIcon = this.el.querySelector("[data-theme-icon='sun']");

    if (moonIcon && sunIcon) {
      moonIcon.classList.toggle("hidden", !isLight);
      sunIcon.classList.toggle("hidden", isLight);
      this.el.setAttribute("aria-label", isLight ? "Switch to dark mode" : "Switch to light mode");
    }
  },
};

Hooks.ScrollShrink = {
  mounted() {
    this.handleScroll = () => {
      const isScrolled = window.scrollY > 20;
      const header = this.el;
      const nav = header.querySelector("nav");
      const logo = header.querySelector("a > div:first-child");
      const logoText = header.querySelector("a > span:first-of-type");

      if (isScrolled) {
        header.classList.remove("pt-6", "pb-12");
        header.classList.add("pt-2", "pb-2");

        if (nav) {
          nav.classList.remove("py-5");
          nav.classList.add("py-3");
        }

        if (logo) {
          logo.classList.remove("w-7", "h-7", "text-sm");
          logo.classList.add("w-6", "h-6", "text-xs");
        }

        if (logoText) {
          logoText.classList.remove("text-base");
          logoText.classList.add("text-sm");
        }
      } else {
        header.classList.add("pt-6", "pb-12");
        header.classList.remove("pt-2", "pb-2");

        if (nav) {
          nav.classList.add("py-5");
          nav.classList.remove("py-3");
        }

        if (logo) {
          logo.classList.add("w-7", "h-7", "text-sm");
          logo.classList.remove("w-6", "h-6", "text-xs");
        }

        if (logoText) {
          logoText.classList.add("text-base");
          logoText.classList.remove("text-sm");
        }
      }
    };

    window.addEventListener("scroll", this.handleScroll);
    this.handleScroll();
  },

  destroyed() {
    window.removeEventListener("scroll", this.handleScroll);
  },
};

// CoreAgentRun — forwards a successful core Agent action (the explicit success
// signal the demo proves after Jido.Agent.cmd/2 returns) to first-party
// analytics as `agent_run_succeeded` (jido-e12-t23). Attached to a demo root
// via phx-hook="CoreAgentRun"; the demo pushes "agent-run-succeeded" only after
// a real action completes, so the event represents success, not a page view.
Hooks.CoreAgentRun = {
  mounted() {
    this.handleEvent("agent-run-succeeded", (payload) => {
      if (typeof window.__agentJidoTrackEvent !== "function") {
        return;
      }

      const example = payload?.example || "core-agent";

      window.__agentJidoTrackEvent("agent_run_succeeded", {
        source: "example",
        channel: "interactive_demo",
        section_id: example,
        target_url: window.location.pathname,
        path: window.location.pathname,
        metadata: {
          surface: "example_demo",
          example: example,
          action: payload?.action,
        },
      });
    });
  },
};

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

function shouldConnectLiveSocket() {
  const userAgent = navigator.userAgent || "";
  const automatedUserAgent = userAgent.includes("HeadlessChrome") || userAgent.includes("Lighthouse");

  return !navigator.webdriver && !automatedUserAgent;
}

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
});

topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", () => topbar.show(300));
window.addEventListener("phx:page-loading-stop", () => {
  topbar.hide();
  syncUtilityTopBarHeight();
  postHogManager.syncForPath(window.location.pathname, { capturePageview: true });
});
window.addEventListener("resize", syncUtilityTopBarHeight);

syncUtilityTopBarHeight();
postHogManager.scheduleInit();

if (shouldConnectLiveSocket()) {
  liveSocket.connect();
}

window.liveSocket = liveSocket;

function trackDatasetAnalyticsEvent(target) {
  const analyticsNode = target.closest("[data-analytics-event]");

  if (!analyticsNode) {
    return;
  }

  trackAnalyticsEvent(analyticsNode.dataset.analyticsEvent, {
    source: analyticsNode.dataset.analyticsSource,
    channel: analyticsNode.dataset.analyticsChannel,
    section_id: analyticsNode.dataset.analyticsSectionId,
    target_url: analyticsNode.dataset.analyticsTargetUrl,
    query_log_id: analyticsNode.dataset.analyticsQueryLogId,
    rank: parsePositiveInt(analyticsNode.dataset.analyticsRank),
    external: analyticsNode.dataset.analyticsExternal,
    provider: analyticsNode.dataset.analyticsProvider,
    package_id: analyticsNode.dataset.analyticsPackageId,
    package_version: analyticsNode.dataset.analyticsPackageVersion,
    page_kind: analyticsNode.dataset.analyticsPageKind,
    path: window.location.pathname,
    metadata: buildDatasetAnalyticsMetadata(analyticsNode),
  });
}

// Collects the optional metadata dimensions carried on data-analytics-*
// attributes (jido-e04-t32). Each home card / CTA carries a card_type so its
// click event records what kind of card routed the visitor, alongside the
// destination (target_url). Attributes that are absent are omitted so events
// without these dimensions post an empty metadata object, unchanged from
// prior behavior.
function buildDatasetAnalyticsMetadata(analyticsNode) {
  const metadata = {};
  const cardType = analyticsNode.dataset.analyticsCardType;

  if (cardType) {
    metadata.card_type = cardType;
  }

  return metadata;
}

function isEditableTarget(target) {
  if (!target) {
    return false;
  }

  if (target.isContentEditable) {
    return true;
  }

  const tagName = target.tagName ? target.tagName.toLowerCase() : "";
  return tagName === "input" || tagName === "textarea" || tagName === "select";
}

function openPrimaryNavSearch() {
  const trigger = document.getElementById("primary-nav-content-assistant-trigger");

  if (trigger) {
    trigger.click();
  }
}

document.addEventListener("keydown", (event) => {
  if (event.defaultPrevented || isEditableTarget(event.target)) {
    return;
  }

  const key = event.key.toLowerCase();
  const hasCommandModifier = event.metaKey || event.ctrlKey;

  if (hasCommandModifier && key === "k") {
    event.preventDefault();
    openPrimaryNavSearch();
    return;
  }

  if (!event.metaKey && !event.ctrlKey && !event.altKey && !event.shiftKey && key === "/") {
    event.preventDefault();
    openPrimaryNavSearch();
  }
});

document.addEventListener("click", (event) => {
  trackDatasetAnalyticsEvent(event.target);

  const livebookLink = event.target.closest("[data-livebook-run='true']");

  if (livebookLink) {
    trackAnalyticsEvent("livebook_run_clicked", {
      source: livebookLink.dataset.analyticsSource || "docs",
      channel: livebookLink.dataset.analyticsChannel || "quick_links",
      target_url: livebookLink.dataset.analyticsTargetUrl || livebookLink.getAttribute("href"),
      path: window.location.pathname,
      metadata: { surface: "docs_page" },
    });
  }

  const copyButton = event.target.closest("[data-copy-button]");

  if (copyButton) {
    event.preventDefault();

    const readCopyContent = async () => {
      const sourceUrl = copyButton.dataset.copySourceUrl;

      if (sourceUrl) {
        const response = await fetch(sourceUrl, {
          headers: {
            Accept: "text/markdown, text/plain;q=0.9, */*;q=0.1",
          },
        });

        if (!response.ok) {
          throw new Error(`Copy source fetch failed with status ${response.status}`);
        }

        return await response.text();
      }

      return copyButton.getAttribute("data-content") || "";
    };

    const successLabel = copyButton.dataset.copySuccessLabel;
    const originalContent = copyButton.innerHTML;

    const successMarkup = successLabel
      ? `<span class="inline-flex items-center gap-1.5"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="h-4 w-4"><path fill-rule="evenodd" d="M19.916 4.626a.75.75 0 01.208 1.04l-9 13.5a.75.75 0 01-1.154.114l-6-6a.75.75 0 011.06-1.06l5.353 5.353 8.493-12.739a.75.75 0 011.04-.208z" clip-rule="evenodd" /></svg><span>${successLabel}</span></span>`
      : `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5">
        <path fill-rule="evenodd" d="M19.916 4.626a.75.75 0 01.208 1.04l-9 13.5a.75.75 0 01-1.154.114l-6-6a.75.75 0 011.06-1.06l5.353 5.353 8.493-12.739a.75.75 0 011.04-.208z" clip-rule="evenodd" />
      </svg>`;

    readCopyContent()
      .then((content) => {
        return navigator.clipboard.writeText(content).then(() => content);
      })
      .then((content) => {
        copyButton.innerHTML = successMarkup;

        setTimeout(() => {
          copyButton.innerHTML = originalContent;
        }, 2000);

        trackAnalyticsEvent("code_copied", {
          source: copyButton.dataset.analyticsSource || "docs",
          channel: copyButton.dataset.analyticsChannel || "copy_button",
          path: window.location.pathname,
          metadata: {
            surface: copyButton.dataset.analyticsSurface || "docs_page",
            content_length: content ? content.length : 0,
            copy_mode: copyButton.dataset.copySourceUrl ? "remote" : "inline",
            source_url: copyButton.dataset.copySourceUrl || null,
          },
        });
      })
      .catch((error) => {
        console.error("Failed to copy content", error);

        trackAnalyticsEvent("copy_failed", {
          source: copyButton.dataset.analyticsSource || "docs",
          channel: copyButton.dataset.analyticsChannel || "copy_button",
          path: window.location.pathname,
          metadata: {
            surface: copyButton.dataset.analyticsSurface || "docs_page",
            copy_mode: copyButton.dataset.copySourceUrl ? "remote" : "inline",
            source_url: copyButton.dataset.copySourceUrl || null,
          },
        });
      });
  }
});
