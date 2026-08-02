import assert from "node:assert/strict";
import test from "node:test";

import { createPostHogManager } from "./posthog_manager.mjs";

function createMockPostHog() {
  return {
    initCalls: [],
    registered: [],
    captured: [],
    configs: [],
    recordingStartedValue: false,
    startedRecordingCount: 0,
    stoppedRecordingCount: 0,
    init(apiKey, options) {
      this.initCalls.push({ apiKey, options });
      options.loaded(this);
    },
    register(payload) {
      this.registered.push(payload);
    },
    capture(eventName, payload) {
      this.captured.push({ eventName, payload });
    },
    set_config(payload) {
      this.configs.push(payload);
    },
    sessionRecordingStarted() {
      return this.recordingStartedValue;
    },
    startSessionRecording() {
      this.recordingStartedValue = true;
      this.startedRecordingCount += 1;
    },
    stopSessionRecording() {
      this.recordingStartedValue = false;
      this.stoppedRecordingCount += 1;
    },
  };
}

function createMockDocument() {
  return {
    visibilityState: "visible",
    listeners: new Map(),
    addEventListener(name, handler) {
      this.listeners.set(name, handler);
    },
    removeEventListener(name) {
      this.listeners.delete(name);
    },
  };
}

test("buffers path syncs and events until PostHog is initialized", async () => {
  const posthog = createMockPostHog();
  let importCount = 0;

  const windowRef = {
    location: {
      pathname: "/blog/jido-2-0-is-here",
      href: "https://jido.run/blog/jido-2-0-is-here",
    },
    __agentJidoPostHog: {
      apiKey: "browser-key",
      apiHost: "https://e.jido.run",
      uiHost: "https://us.posthog.com",
      distinctId: "visitor-id",
      sessionId: "session-id",
      currentPath: "/blog/jido-2-0-is-here",
      autocaptureEnabled: true,
      sessionReplayEnabled: true,
      sessionReplaySampleRate: 1,
      pathIgnorePrefixes: ["/admin"],
      pathIgnoreExactPaths: [],
      blockClass: "ph-no-capture",
      maskTextClass: "ph-mask",
      maskAllInputs: true,
    },
  };

  const manager = createPostHogManager({
    windowRef,
    documentRef: createMockDocument(),
    importPostHog: async () => {
      importCount += 1;
      return { default: posthog };
    },
    setTimeoutFn: setTimeout,
    clearTimeoutFn: clearTimeout,
  });

  manager.syncForPath("/blog/jido-2-0-is-here", { capturePageview: true });
  manager.trackEvent("code_copied", {
    path: "/blog/jido-2-0-is-here",
    metadata: { surface: "docs_page" },
    query: "secret query text",
  });

  await manager.initNow();

  assert.equal(importCount, 1);
  assert.deepEqual(
    posthog.captured.map((entry) => entry.eventName),
    ["$pageview", "code_copied"]
  );
  assert.equal(posthog.startedRecordingCount, 1);
  assert.equal(posthog.stoppedRecordingCount, 0);
  assert.equal(posthog.initCalls[0].options.capture_dead_clicks, false);
  assert.equal(posthog.initCalls[0].options.capture_exceptions, false);
  assert.equal(posthog.initCalls[0].options.capture_performance, false);
  assert.equal(posthog.initCalls[0].options.disable_surveys, true);
  assert.equal(posthog.initCalls[0].options.rageclick, false);
  assert.equal(posthog.captured[0].payload.path, "/blog/jido-2-0-is-here");
  assert.equal(posthog.captured[1].payload.surface, "docs_page");
  assert.equal(posthog.captured[1].payload.query_length, "secret query text".length);
  assert.ok(!Object.hasOwn(posthog.captured[1].payload, "query"));
});

test("defers PostHog import until the delay and idle work run", async () => {
  const posthog = createMockPostHog();
  let idleCallback = null;
  let importCount = 0;
  let timeoutCallback = null;

  const manager = createPostHogManager({
    windowRef: {
      location: { pathname: "/", href: "https://jido.run/" },
      __agentJidoPostHog: {
        apiKey: "browser-key",
        apiHost: "https://e.jido.run",
        uiHost: "https://us.posthog.com",
        distinctId: "visitor-id",
        sessionId: "session-id",
        currentPath: "/",
        autocaptureEnabled: false,
        sessionReplayEnabled: false,
        sessionReplaySampleRate: 0,
        pathIgnorePrefixes: [],
        pathIgnoreExactPaths: [],
      },
    },
    documentRef: createMockDocument(),
    importPostHog: async () => {
      importCount += 1;
      return { default: posthog };
    },
    requestIdleCallbackFn: (callback) => {
      idleCallback = callback;
      return 1;
    },
    cancelIdleCallbackFn: () => {},
    setTimeoutFn: (callback) => {
      timeoutCallback = callback;
      return 2;
    },
    clearTimeoutFn: () => {},
  });

  manager.scheduleInit();

  assert.equal(importCount, 0);
  assert.equal(idleCallback, null);
  assert.ok(typeof timeoutCallback === "function");

  timeoutCallback();
  assert.ok(typeof idleCallback === "function");
  idleCallback();
  await manager.state.initPromise;

  assert.equal(importCount, 1);
  assert.equal(posthog.initCalls.length, 1);
});

test("falls back to timeout when requestIdleCallback is unavailable", async () => {
  const posthog = createMockPostHog();
  let importCount = 0;
  let timeoutCallback = null;

  const manager = createPostHogManager({
    windowRef: {
      location: { pathname: "/", href: "https://jido.run/" },
      __agentJidoPostHog: {
        apiKey: "browser-key",
        apiHost: "https://e.jido.run",
        uiHost: "https://us.posthog.com",
        distinctId: "visitor-id",
        sessionId: "session-id",
        currentPath: "/",
        autocaptureEnabled: false,
        sessionReplayEnabled: false,
        sessionReplaySampleRate: 0,
        pathIgnorePrefixes: [],
        pathIgnoreExactPaths: [],
      },
    },
    documentRef: createMockDocument(),
    importPostHog: async () => {
      importCount += 1;
      return { default: posthog };
    },
    setTimeoutFn: (callback) => {
      timeoutCallback = callback;
      return 2;
    },
    clearTimeoutFn: () => {},
  });

  manager.scheduleInit();

  assert.equal(importCount, 0);
  assert.ok(typeof timeoutCallback === "function");

  timeoutCallback();
  await manager.state.initPromise;

  assert.equal(importCount, 1);
  assert.equal(posthog.initCalls.length, 1);
});
