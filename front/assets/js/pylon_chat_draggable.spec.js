import { expect } from "chai";
import sinon from "sinon";
import { initPylonChatDraggable } from "./pylon_chat_draggable";

const CONTAINER_CLASS = "PylonChat-bubbleFrameContainer";
const VISIBLE_CLASS = "PylonChat-bubbleFrameContainer--visible";
const OVERLAY_CLASS = "PylonChat-dragOverlay";
const DRAGGABLE_DATA_ATTRIBUTE = "pylonDraggableReady";
const STORAGE_KEY = "pylon_chat_bubble_position";
const CHAT_WINDOW_ID = "pylon-chat-window";

function createMockLocalStorage() {
  const storage = new Map();

  return {
    getItem(key) {
      return storage.has(key) ? storage.get(key) : null;
    },
    setItem(key, value) {
      storage.set(key, String(value));
    },
    removeItem(key) {
      storage.delete(key);
    },
    clear() {
      storage.clear();
    }
  };
}

function setViewport(width, height) {
  Object.defineProperty(window, "innerWidth", {
    configurable: true,
    writable: true,
    value: width
  });
  Object.defineProperty(window, "innerHeight", {
    configurable: true,
    writable: true,
    value: height
  });
}

function createContainer({
  left = 100,
  top = 100,
  width = 60,
  height = 60,
  visible = true
} = {}) {
  const container = document.createElement("div");
  container.className = CONTAINER_CLASS;
  if (visible) container.classList.add(VISIBLE_CLASS);

  container.getBoundingClientRect = () => {
    const styleLeft = Number.parseFloat(container.style.left);
    const styleTop = Number.parseFloat(container.style.top);
    const resolvedLeft = Number.isNaN(styleLeft) ? left : styleLeft;
    const resolvedTop = Number.isNaN(styleTop) ? top : styleTop;

    return {
      left: resolvedLeft,
      top: resolvedTop,
      width,
      height,
      right: resolvedLeft + width,
      bottom: resolvedTop + height
    };
  };

  document.body.appendChild(container);
  return container;
}

function createPointerEvent(type, { x, y, button = 0, pointerId = 1, pointerType = "mouse" } = {}) {
  const pointerEventInit = {
    bubbles: true,
    cancelable: true,
    clientX: x,
    clientY: y,
    button,
    pointerId,
    pointerType
  };

  if (typeof window.PointerEvent === "function") {
    return new window.PointerEvent(type, pointerEventInit);
  }

  const fallbackEvent =
    typeof window.Event === "function"
      ? new window.Event(type, { bubbles: true, cancelable: true })
      : (() => {
          const event = document.createEvent("Event");
          event.initEvent(type, true, true);
          return event;
        })();

  Object.defineProperty(fallbackEvent, "clientX", { value: x || 0 });
  Object.defineProperty(fallbackEvent, "clientY", { value: y || 0 });
  Object.defineProperty(fallbackEvent, "button", { value: button });
  Object.defineProperty(fallbackEvent, "pointerId", { value: pointerId });
  Object.defineProperty(fallbackEvent, "pointerType", { value: pointerType });

  return fallbackEvent;
}

function dispatchPointerEvent(target, type, { x, y, button = 0, pointerId = 1, pointerType = "mouse" } = {}) {
  target.dispatchEvent(createPointerEvent(type, { x, y, button, pointerId, pointerType }));
}

function clickOverlay(overlay, x = 100, y = 100) {
  dispatchPointerEvent(overlay, "pointerdown", { x, y });
  dispatchPointerEvent(overlay, "pointerup", { x, y });
}

function createChatWindow({
  width = 320,
  height = 480,
  display = "block",
  visibility = "visible",
  opacity = "1"
} = {}) {
  const chatWindow = document.createElement("iframe");
  chatWindow.id = CHAT_WINDOW_ID;
  chatWindow.style.display = display;
  chatWindow.style.visibility = visibility;
  chatWindow.style.opacity = opacity;

  chatWindow.getBoundingClientRect = () => ({
    left: 0,
    top: 0,
    width,
    height,
    right: width,
    bottom: height
  });

  document.body.appendChild(chatWindow);
  return chatWindow;
}

describe("initPylonChatDraggable", () => {
  let sandbox;
  let originalLocalStorageDescriptor;
  let originalMutationObserver;
  let registeredObservers;

  beforeEach(() => {
    sandbox = sinon.createSandbox();
    document.body.innerHTML = "";
    setViewport(200, 200);

    originalLocalStorageDescriptor = Object.getOwnPropertyDescriptor(window, "localStorage");
    Object.defineProperty(window, "localStorage", {
      configurable: true,
      writable: true,
      value: createMockLocalStorage()
    });

    originalMutationObserver = window.MutationObserver;
    registeredObservers = [];

    class MockMutationObserver {
      constructor(callback) {
        this.callback = callback;
        this.disconnected = false;
        registeredObservers.push(this);
      }

      observe() {}

      disconnect() {
        this.disconnected = true;
      }

      trigger(records) {
        if (!this.disconnected) this.callback(records);
      }
    }

    window.MutationObserver = MockMutationObserver;
    globalThis.MutationObserver = MockMutationObserver;

    window.pylon = { chat_settings: { app_id: "test-app-id" } };
    window.Pylon = sandbox.spy();
  });

  afterEach(() => {
    if (
      typeof window.dispatchEvent === "function" &&
      typeof window.Event === "function"
    ) {
      window.dispatchEvent(new window.Event("beforeunload"));
    }

    sandbox.restore();
    delete window.pylon;
    delete window.Pylon;
    if (originalLocalStorageDescriptor) {
      Object.defineProperty(window, "localStorage", originalLocalStorageDescriptor);
    } else {
      delete window.localStorage;
    }
    window.MutationObserver = originalMutationObserver;
    globalThis.MutationObserver = originalMutationObserver;
    document.body.innerHTML = "";
  });

  it("toggles using chat window visibility state", () => {
    const container = createContainer({ visible: true });
    initPylonChatDraggable();

    const overlay = container.querySelector(`.${OVERLAY_CLASS}`);
    clickOverlay(overlay, 100, 100);
    expect(window.Pylon.firstCall.args[0]).to.equal("show");

    const chatWindow = createChatWindow();
    clickOverlay(overlay, 100, 100);
    expect(window.Pylon.secondCall.args[0]).to.equal("hide");

    chatWindow.remove();
    clickOverlay(overlay, 100, 100);
    expect(window.Pylon.thirdCall.args[0]).to.equal("show");
  });

  it("treats hidden chat window iframe as closed state", () => {
    const container = createContainer({ visible: true });
    initPylonChatDraggable();
    const overlay = container.querySelector(`.${OVERLAY_CLASS}`);

    createChatWindow({ display: "none" });
    clickOverlay(overlay, 100, 100);

    expect(window.Pylon.calledOnce).to.equal(true);
    expect(window.Pylon.firstCall.args[0]).to.equal("show");
  });

  it("uses drag threshold to separate click from drag behavior", () => {
    const container = createContainer({ visible: true });
    initPylonChatDraggable();
    const overlay = container.querySelector(`.${OVERLAY_CLASS}`);

    dispatchPointerEvent(overlay, "pointerdown", { x: 100, y: 100 });
    dispatchPointerEvent(overlay, "pointermove", { x: 103, y: 103 });
    dispatchPointerEvent(overlay, "pointerup", { x: 103, y: 103 });

    expect(window.Pylon.calledOnce).to.equal(true);
    expect(window.localStorage.getItem(STORAGE_KEY)).to.equal(null);

    window.Pylon.resetHistory();

    dispatchPointerEvent(overlay, "pointerdown", { x: 100, y: 100 });
    dispatchPointerEvent(overlay, "pointermove", { x: 106, y: 106 });
    dispatchPointerEvent(overlay, "pointerup", { x: 106, y: 106 });

    expect(window.Pylon.called).to.equal(false);

    const savedPosition = JSON.parse(window.localStorage.getItem(STORAGE_KEY));
    expect(savedPosition.x).to.be.a("number");
    expect(savedPosition.y).to.be.a("number");
  });

  it("clamps persisted position into the viewport", () => {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ x: -500, y: 500 }));
    const container = createContainer({ width: 60, height: 60, visible: true });

    initPylonChatDraggable();

    expect(container.style.left).to.equal("8px");
    expect(container.style.top).to.equal("132px");
  });

  it("is idempotent when initialized more than once", () => {
    const container = createContainer({ visible: true });
    initPylonChatDraggable();
    initPylonChatDraggable();

    const overlays = container.querySelectorAll(`.${OVERLAY_CLASS}`);
    expect(overlays.length).to.equal(1);
    expect(container.dataset[DRAGGABLE_DATA_ATTRIBUTE]).to.equal("true");

    clickOverlay(overlays[0], 100, 100);
    expect(window.Pylon.calledOnce).to.equal(true);
  });

  it("initializes draggable behavior for containers added after startup", async () => {
    initPylonChatDraggable();

    const container = createContainer({ visible: true });
    registeredObservers[0].trigger([{ addedNodes: [container] }]);
    await Promise.resolve();

    expect(container.dataset[DRAGGABLE_DATA_ATTRIBUTE]).to.equal("true");
    expect(container.querySelectorAll(`.${OVERLAY_CLASS}`).length).to.equal(1);
  });
});
