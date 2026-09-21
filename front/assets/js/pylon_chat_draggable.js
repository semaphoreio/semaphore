const PYLON_CHAT_CONTAINER_SELECTOR = ".PylonChat-bubbleFrameContainer";
const PYLON_CHAT_WINDOW_SELECTOR = "#pylon-chat-window";
const DRAGGABLE_CLASS = "PylonChat-bubbleFrameContainer--draggable";
const DRAGGING_CLASS = "PylonChat-bubbleFrameContainer--dragging";
const DRAG_OVERLAY_CLASS = "PylonChat-dragOverlay";
const STORAGE_KEY = "pylon_chat_bubble_position";
const VIEWPORT_MARGIN = 8;
const DRAG_THRESHOLD_PX = 3;

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function safeReadPosition() {
  try {
    const serialized = window.localStorage.getItem(STORAGE_KEY);
    if (!serialized) return null;

    const parsed = JSON.parse(serialized);
    if (typeof parsed.x !== "number" || typeof parsed.y !== "number") return null;

    return parsed;
  } catch {
    return null;
  }
}

function safeWritePosition(position) {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(position));
  } catch {
    // Ignore storage failures (private mode, disabled storage, etc).
  }
}

function applyPosition(container, { x, y }) {
  const rect = container.getBoundingClientRect();
  const maxX = Math.max(VIEWPORT_MARGIN, window.innerWidth - rect.width - VIEWPORT_MARGIN);
  const maxY = Math.max(VIEWPORT_MARGIN, window.innerHeight - rect.height - VIEWPORT_MARGIN);
  const clampedX = clamp(x, VIEWPORT_MARGIN, maxX);
  const clampedY = clamp(y, VIEWPORT_MARGIN, maxY);

  container.style.position = "fixed";
  container.style.left = `${Math.round(clampedX)}px`;
  container.style.top = `${Math.round(clampedY)}px`;
  container.style.right = "auto";
  container.style.bottom = "auto";
}

function ensureDragOverlay(container) {
  const existingOverlay = container.querySelector(`.${DRAG_OVERLAY_CLASS}`);
  if (existingOverlay) return existingOverlay;

  const overlay = document.createElement("div");
  overlay.className = DRAG_OVERLAY_CLASS;
  overlay.setAttribute("aria-hidden", "true");
  container.appendChild(overlay);

  return overlay;
}

function isPylonReady() {
  return typeof window.Pylon === "function";
}

function isElementVisible(element) {
  if (!element) return false;

  if (
    element.style &&
    (element.style.display === "none" ||
      element.style.visibility === "hidden" ||
      element.style.opacity === "0")
  ) {
    return false;
  }

  if (typeof window.getComputedStyle === "function") {
    const computedStyle = window.getComputedStyle(element);
    if (
      computedStyle.display === "none" ||
      computedStyle.visibility === "hidden" ||
      computedStyle.opacity === "0"
    ) {
      return false;
    }
  }

  if (typeof element.getBoundingClientRect === "function") {
    const rect = element.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return false;
  }

  return true;
}

function isPylonChatWindowVisible() {
  const chatWindow = document.querySelector(PYLON_CHAT_WINDOW_SELECTOR);
  return isElementVisible(chatWindow);
}

function togglePylonChat() {
  if (!isPylonReady()) return;

  const shouldHideChat = isPylonChatWindowVisible();
  try {
    window.Pylon(shouldHideChat ? "hide" : "show");
  } catch {
    // If toggle fails, prefer opening over doing nothing.
    window.Pylon("show");
  }
}

function makeContainerDraggable(container) {
  if (container.dataset.pylonDraggableReady === "true") return;
  container.dataset.pylonDraggableReady = "true";
  container.classList.add(DRAGGABLE_CLASS);

  const savedPosition = safeReadPosition();
  if (savedPosition) applyPosition(container, savedPosition);

  const overlay = ensureDragOverlay(container);
  let dragState = null;

  const finishDrag = () => {
    if (!dragState) return;

    container.classList.remove(DRAGGING_CLASS);

    if (dragState.didMove) {
      const finalRect = container.getBoundingClientRect();
      safeWritePosition({ x: finalRect.left, y: finalRect.top });
    } else {
      togglePylonChat();
    }

    dragState = null;
  };

  const onPointerMove = (event) => {
    if (!dragState || event.pointerId !== dragState.pointerId) return;

    if (!dragState.didMove) {
      const deltaX = Math.abs(event.clientX - dragState.startClientX);
      const deltaY = Math.abs(event.clientY - dragState.startClientY);
      dragState.didMove = deltaX > DRAG_THRESHOLD_PX || deltaY > DRAG_THRESHOLD_PX;

      if (dragState.didMove) {
        container.classList.add(DRAGGING_CLASS);
      }
    }

    if (dragState.didMove) {
      const nextX = event.clientX - dragState.pointerOffsetX;
      const nextY = event.clientY - dragState.pointerOffsetY;
      applyPosition(container, { x: nextX, y: nextY });
      event.preventDefault();
    }
  };

  const onPointerUp = (event) => {
    if (!dragState || event.pointerId !== dragState.pointerId) return;
    finishDrag();
  };

  const onPointerCancel = (event) => {
    if (!dragState || event.pointerId !== dragState.pointerId) return;
    finishDrag();
  };

  const onPointerDown = (event) => {
    if (dragState) return;
    if (event.pointerType === "mouse" && event.button !== 0) return;

    const rect = container.getBoundingClientRect();
    dragState = {
      pointerId: event.pointerId,
      pointerOffsetX: event.clientX - rect.left,
      pointerOffsetY: event.clientY - rect.top,
      startClientX: event.clientX,
      startClientY: event.clientY,
      didMove: false
    };

    if (typeof overlay.setPointerCapture === "function") {
      try {
        overlay.setPointerCapture(event.pointerId);
      } catch {
        // Not supported on all browsers
      }
    }

    event.preventDefault();
  };

  overlay.addEventListener("pointerdown", onPointerDown);
  overlay.addEventListener("pointermove", onPointerMove);
  overlay.addEventListener("pointerup", onPointerUp);
  overlay.addEventListener("pointercancel", onPointerCancel);
}

export function initPylonChatDraggable() {
  if (!document.body || !window.pylon || !window.pylon.chat_settings) return;

  const initializeContainerTree = (rootNode) => {
    if (rootNode.nodeType !== Node.ELEMENT_NODE) return;

    const rootElement = rootNode;
    if (rootElement.matches(PYLON_CHAT_CONTAINER_SELECTOR)) {
      makeContainerDraggable(rootElement);
    }

    rootElement
      .querySelectorAll(PYLON_CHAT_CONTAINER_SELECTOR)
      .forEach(makeContainerDraggable);
  };

  document
    .querySelectorAll(PYLON_CHAT_CONTAINER_SELECTOR)
    .forEach(makeContainerDraggable);

  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach(initializeContainerTree);
    });
  });

  observer.observe(document.body, { childList: true, subtree: true });

  if (typeof window.addEventListener === "function") {
    window.addEventListener("beforeunload", () => observer.disconnect(), { once: true });
  }
}
