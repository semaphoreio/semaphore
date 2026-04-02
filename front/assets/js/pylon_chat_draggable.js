const PYLON_CHAT_CONTAINER_SELECTOR = ".PylonChat-bubbleFrameContainer";
const DRAGGABLE_CLASS = "PylonChat-bubbleFrameContainer--draggable";
const DRAGGING_CLASS = "PylonChat-bubbleFrameContainer--dragging";
const DRAG_OVERLAY_CLASS = "PylonChat-dragOverlay";
const STORAGE_KEY = "pylon_chat_bubble_position";
const VIEWPORT_MARGIN = 8;
const DRAG_THRESHOLD_PX = 3;
let pylonChatVisible = false;

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

function togglePylonChat() {
  if (!isPylonReady()) return;

  const nextVisibleState = !pylonChatVisible;
  try {
    window.Pylon(nextVisibleState ? "show" : "hide");
    pylonChatVisible = nextVisibleState;
  } catch {
    // If toggle fails, prefer opening over doing nothing.
    window.Pylon("show");
    pylonChatVisible = true;
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

  const onMouseMove = (event) => {
    if (!dragState) return;

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

  const onMouseUp = () => {
    if (!dragState) return;

    document.removeEventListener("mousemove", onMouseMove);
    document.removeEventListener("mouseup", onMouseUp);
    container.classList.remove(DRAGGING_CLASS);

    if (dragState.didMove) {
      const finalRect = container.getBoundingClientRect();
      safeWritePosition({ x: finalRect.left, y: finalRect.top });
    } else {
      togglePylonChat();
    }

    dragState = null;
  };

  const onMouseDown = (event) => {
    if (event.button !== 0 || dragState) return;

    const rect = container.getBoundingClientRect();
    dragState = {
      pointerOffsetX: event.clientX - rect.left,
      pointerOffsetY: event.clientY - rect.top,
      startClientX: event.clientX,
      startClientY: event.clientY,
      didMove: false
    };

    document.addEventListener("mousemove", onMouseMove);
    document.addEventListener("mouseup", onMouseUp);
    event.preventDefault();
  };

  overlay.addEventListener("mousedown", onMouseDown);
}

export function initPylonChatDraggable() {
  if (!document.body || !window.pylon || !window.pylon.chat_settings) return;

  const initializeVisibleContainers = () => {
    document.querySelectorAll(PYLON_CHAT_CONTAINER_SELECTOR).forEach(makeContainerDraggable);
  };

  initializeVisibleContainers();

  const observer = new MutationObserver(() => {
    initializeVisibleContainers();
  });

  observer.observe(document.body, { childList: true, subtree: true });
  window.addEventListener("beforeunload", () => observer.disconnect(), { once: true });
}
