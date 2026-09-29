export var DiagramDrag = {
  init: function () {
    var container = document.getElementById("diagram");
    if (!container) return;

    //
    // Under Turbo Drive init() runs again on every visit to the workflow view.
    // The mousemove/mouseup listeners live on window and the cursor style tag
    // on document.head, neither of which is replaced by the body swap, so drop
    // the previous page's set before installing this one.
    //
    this.stop();

    var state = { active: false, startX: 0, startY: 0, scrollLeft: 0, pageScrollTop: 0 };

    function isPipelineContent(e) {
      return !!e.target.closest(".drag-ignore");
    }

    container.addEventListener("mousedown", function (e) {
      var isLeft = e.button === 0;
      var isMiddle = e.button === 1;

      if (!isLeft && !isMiddle) return;
      if (isLeft && isPipelineContent(e)) return;
      if (isMiddle) e.preventDefault();

      state.active = true;
      state.startX = e.pageX;
      state.startY = e.pageY;
      state.scrollLeft = container.scrollLeft;
      state.pageScrollTop = window.scrollY;
      container.style.cursor = "grabbing";
      container.style.userSelect = "none"; // njsscan-ignore: node_username
    });

    this.onMouseMove = function (e) {
      if (!state.active) return;

      if (e.buttons === 0) {
        state.active = false;
        container.style.cursor = "grab";
        container.style.userSelect = "";
        return;
      }

      e.preventDefault();
      container.scrollLeft = state.scrollLeft - (e.pageX - state.startX);
      var scrollDelta = window.scrollY - state.pageScrollTop;
      var dy = e.pageY - state.startY - scrollDelta;
      window.scrollTo(0, state.pageScrollTop - dy);
    };

    this.onMouseUp = function () {
      if (!state.active) return;
      state.active = false;
      container.style.cursor = "grab";
      container.style.userSelect = "";
    };

    window.addEventListener("mousemove", this.onMouseMove);
    window.addEventListener("mouseup", this.onMouseUp);

    container.style.cursor = "grab";

    this.style = document.createElement("style");
    this.style.textContent = "#diagram .drag-ignore, #diagram .drag-ignore * { cursor: default; }";
    document.head.appendChild(this.style);
  },

  //
  // The mousedown listener is bound to #diagram, which Turbo discards along
  // with the rest of the body, so only the window listeners and the style tag
  // have to be released here.
  //
  stop: function () {
    if (this.onMouseMove) {
      window.removeEventListener("mousemove", this.onMouseMove);
      this.onMouseMove = null;
    }

    if (this.onMouseUp) {
      window.removeEventListener("mouseup", this.onMouseUp);
      this.onMouseUp = null;
    }

    if (this.style) {
      this.style.remove();
      this.style = null;
    }
  }
};
