export const POSTHOG_BROWSER_EVENTS = new Set([
  "docs_section_viewed",
  "code_copied",
  "livebook_run_clicked",
  "content_assistant_reference_clicked",
  "content_assistant_answer_link_clicked",
]);

const DEFAULT_INTERACTION_EVENTS = ["pointerdown", "keydown", "touchstart"];

export function normalizePath(path, fallbackPath = "/") {
  if (typeof path === "string" && path.startsWith("/")) {
    return path;
  }

  return typeof fallbackPath === "string" && fallbackPath.startsWith("/") ? fallbackPath : "/";
}

export function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

export function stringLength(value) {
  return typeof value === "string" ? value.length : undefined;
}

export function flattenAnalyticsProperties(properties = {}, { fallbackPath = "/" } = {}) {
  const normalizedPath = normalizePath(properties.path, fallbackPath);
  const metadata = isPlainObject(properties.metadata) ? properties.metadata : {};
  const flattened = {
    ...properties,
    ...metadata,
    path: normalizedPath,
  };

  delete flattened.metadata;

  const queryLength =
    stringLength(flattened.query) ||
    stringLength(flattened.query_text) ||
    stringLength(metadata.query) ||
    stringLength(metadata.query_text);

  const feedbackNoteLength =
    stringLength(flattened.feedback_note) ||
    stringLength(flattened.note) ||
    stringLength(metadata.feedback_note) ||
    stringLength(metadata.note);

  if (queryLength !== undefined) {
    flattened.query_length = queryLength;
  }

  if (feedbackNoteLength !== undefined) {
    flattened.feedback_note_length = feedbackNoteLength;
  }

  delete flattened.query;
  delete flattened.query_text;
  delete flattened.feedback_note;
  delete flattened.note;
  delete flattened.answer_html;
  delete flattened.answer_markdown;
  delete flattened.citations;
  delete flattened.related_queries;

  return flattened;
}

function hashToUnitInterval(value) {
  const input = typeof value === "string" && value.length > 0 ? value : "posthog";
  let hash = 0;

  for (let index = 0; index < input.length; index += 1) {
    hash = (hash * 31 + input.charCodeAt(index)) >>> 0;
  }

  return hash / 0xffffffff;
}

function createAutocaptureConfig(config) {
  if (!config.autocaptureEnabled) {
    return false;
  }

  return {
    url_ignorelist: [
      ...(Array.isArray(config.pathIgnorePrefixes) ? config.pathIgnorePrefixes : []),
      ...(Array.isArray(config.pathIgnoreExactPaths) ? config.pathIgnoreExactPaths : []),
    ],
    capture_copied_text: false,
  };
}

function supportsPostHogMethod(posthog, methodName) {
  return posthog && typeof posthog[methodName] === "function";
}

export function createPostHogManager({
  windowRef,
  documentRef,
  importPostHog,
  requestIdleCallbackFn,
  cancelIdleCallbackFn,
  setTimeoutFn,
  clearTimeoutFn,
  initIdleTimeoutMs = 2_000,
  initFallbackDelayMs = 8_000,
  interactionEvents = DEFAULT_INTERACTION_EVENTS,
} = {}) {
  const timeout = typeof setTimeoutFn === "function" ? setTimeoutFn : setTimeout;
  const clearTimeoutRef = typeof clearTimeoutFn === "function" ? clearTimeoutFn : clearTimeout;

  const state = {
    posthog: null,
    initialized: false,
    initPromise: null,
    replaySampled: false,
    autocaptureConfig: false,
    lastTrackedPath: null,
    pendingOperations: [],
    initIdleCallbackId: null,
    initTimeoutId: null,
    listenersAttached: false,
  };

  const interactionHandler = () => {
    void initNow();
  };

  const visibilityHandler = () => {
    if (documentRef?.visibilityState === "visible") {
      void initNow();
    }
  };

  function clearScheduledInit() {
    if (state.initIdleCallbackId !== null && typeof cancelIdleCallbackFn === "function") {
      cancelIdleCallbackFn(state.initIdleCallbackId);
    }

    if (state.initTimeoutId !== null) {
      clearTimeoutRef(state.initTimeoutId);
    }

    state.initIdleCallbackId = null;
    state.initTimeoutId = null;
  }

  function detachInitListeners() {
    if (!state.listenersAttached || !documentRef) {
      return;
    }

    interactionEvents.forEach((eventName) => {
      documentRef.removeEventListener(eventName, interactionHandler, true);
    });

    documentRef.removeEventListener("visibilitychange", visibilityHandler);
    state.listenersAttached = false;
  }

  function attachInitListeners() {
    if (state.listenersAttached || !documentRef) {
      return;
    }

    interactionEvents.forEach((eventName) => {
      documentRef.addEventListener(eventName, interactionHandler, { capture: true, once: true, passive: true });
    });

    documentRef.addEventListener("visibilitychange", visibilityHandler);
    state.listenersAttached = true;
  }

  function readConfig() {
    return isPlainObject(windowRef?.__agentJidoPostHog) ? windowRef.__agentJidoPostHog : null;
  }

  function isPathEligible(path) {
    const config = readConfig();
    const normalizedPath = normalizePath(path, windowRef?.location?.pathname || "/");

    if (!config) {
      return false;
    }

    const ignoredPrefixes = Array.isArray(config.pathIgnorePrefixes) ? config.pathIgnorePrefixes : [];
    const ignoredExactPaths = Array.isArray(config.pathIgnoreExactPaths) ? config.pathIgnoreExactPaths : [];

    if (ignoredExactPaths.includes(normalizedPath)) {
      return false;
    }

    return !ignoredPrefixes.some((prefix) => normalizedPath.startsWith(prefix));
  }

  function queueOperation(operation) {
    state.pendingOperations.push(operation);
  }

  function flushPendingOperations() {
    if (!state.initialized || !state.posthog) {
      return;
    }

    while (state.pendingOperations.length > 0) {
      const operation = state.pendingOperations.shift();

      try {
        operation();
      } catch (_error) {
        // Drop failed browser analytics work instead of breaking app execution.
      }
    }
  }

  function trackPageview(path) {
    const normalizedPath = normalizePath(path, windowRef?.location?.pathname || "/");

    if (!state.initialized || !state.posthog || !isPathEligible(normalizedPath)) {
      return;
    }

    if (state.lastTrackedPath === normalizedPath) {
      return;
    }

    state.posthog.register({
      current_path: normalizedPath,
    });

    state.posthog.capture("$pageview", {
      path: normalizedPath,
      current_path: normalizedPath,
      $current_url: windowRef?.location?.href,
    });

    state.lastTrackedPath = normalizedPath;
  }

  function syncForPath(path, { capturePageview = false } = {}) {
    const normalizedPath = normalizePath(path, windowRef?.location?.pathname || "/");

    const operation = () => {
      const config = readConfig();

      if (!config || !state.posthog) {
        return;
      }

      const eligible = isPathEligible(normalizedPath);

      state.posthog.register({
        current_path: normalizedPath,
        session_id: config.sessionId,
      });

      if (supportsPostHogMethod(state.posthog, "set_config")) {
        state.posthog.set_config({
          autocapture: eligible ? state.autocaptureConfig : false,
          capture_pageleave: eligible,
        });
      }

      const recordingStarted =
        supportsPostHogMethod(state.posthog, "sessionRecordingStarted") &&
        state.posthog.sessionRecordingStarted();

      if (config.sessionReplayEnabled && state.replaySampled && eligible) {
        if (!recordingStarted && supportsPostHogMethod(state.posthog, "startSessionRecording")) {
          state.posthog.startSessionRecording();
        }
      } else if (recordingStarted && supportsPostHogMethod(state.posthog, "stopSessionRecording")) {
        state.posthog.stopSessionRecording();
      }

      if (capturePageview) {
        trackPageview(normalizedPath);
      }
    };

    if (state.initialized && state.posthog) {
      operation();
    } else {
      scheduleInit();
      queueOperation(operation);
    }
  }

  function trackEvent(eventName, properties = {}) {
    if (!POSTHOG_BROWSER_EVENTS.has(eventName)) {
      return;
    }

    const fallbackPath = windowRef?.location?.pathname || "/";
    const normalizedProperties = {
      ...properties,
      path: normalizePath(properties.path, fallbackPath),
    };

    const operation = () => {
      if (!state.posthog || !isPathEligible(normalizedProperties.path)) {
        return;
      }

      state.posthog.capture(
        eventName,
        flattenAnalyticsProperties(normalizedProperties, { fallbackPath })
      );
    };

    if (state.initialized && state.posthog) {
      operation();
    } else {
      scheduleInit();
      queueOperation(operation);
    }
  }

  async function initNow() {
    const config = readConfig();

    if (!config || !config.apiKey || !config.distinctId || !config.sessionId || typeof importPostHog !== "function") {
      return null;
    }

    if (state.initialized && state.posthog) {
      flushPendingOperations();
      return state.posthog;
    }

    if (state.initPromise) {
      return state.initPromise;
    }

    clearScheduledInit();
    detachInitListeners();

    state.initPromise = Promise.resolve()
      .then(() => importPostHog())
      .then((module) => {
        const posthog = module?.default || module;

        if (!posthog || typeof posthog.init !== "function") {
          return null;
        }

        state.posthog = posthog;
        state.replaySampled =
          Number(config.sessionReplaySampleRate) >= 1 ||
          hashToUnitInterval(config.sessionId) < Number(config.sessionReplaySampleRate || 0);
        state.autocaptureConfig = createAutocaptureConfig(config);

        const initialPath = normalizePath(config.currentPath, windowRef?.location?.pathname || "/");
        const initialPageleaveEnabled = isPathEligible(initialPath);

        return new Promise((resolve) => {
          posthog.init(config.apiKey, {
            api_host: config.apiHost,
            ui_host: config.uiHost,
            bootstrap: {
              distinctID: config.distinctId,
              sessionID: config.sessionId,
            },
            autocapture: false,
            capture_pageview: false,
            capture_pageleave: initialPageleaveEnabled,
            capture_dead_clicks: false,
            capture_exceptions: false,
            capture_performance: false,
            disable_session_recording: true,
            disable_surveys: true,
            mask_all_text: false,
            rageclick: false,
            session_recording: {
              blockClass: config.blockClass || "ph-no-capture",
              maskTextClass: config.maskTextClass || "ph-mask",
              maskAllInputs: config.maskAllInputs !== false,
            },
            loaded(instance) {
              instance.register({
                session_id: config.sessionId,
                current_path: initialPath,
              });

              state.initialized = true;
              queueOperation(() => syncForPath(windowRef?.location?.pathname || initialPath, { capturePageview: true }));
              flushPendingOperations();
              resolve(instance);
            },
          });
        });
      })
      .catch(() => {
        state.initPromise = null;
        state.posthog = null;
        state.initialized = false;
        return null;
      });

    return state.initPromise;
  }

  function scheduleInit() {
    if (!readConfig() || state.initialized || state.initPromise || state.initIdleCallbackId !== null || state.initTimeoutId !== null) {
      return;
    }

    attachInitListeners();

    state.initTimeoutId = timeout(() => {
      state.initTimeoutId = null;

      if (typeof requestIdleCallbackFn === "function") {
        state.initIdleCallbackId = requestIdleCallbackFn(
          () => {
            state.initIdleCallbackId = null;
            void initNow();
          },
          { timeout: initIdleTimeoutMs }
        );
      } else {
        void initNow();
      }
    }, initFallbackDelayMs);
  }

  return {
    scheduleInit,
    initNow,
    readConfig,
    isPathEligible,
    syncForPath,
    trackEvent,
    flushPendingOperations,
    state,
  };
}
