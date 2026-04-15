export var DiagramDrag = {
  init: function () {
    var container = document.getElementById("diagram");
    if (!container) return;

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

    window.addEventListener("mousemove", function (e) {
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
    });

    window.addEventListener("mouseup", function () {
      if (!state.active) return;
      state.active = false;
      container.style.cursor = "grab";
      container.style.userSelect = "";
    });

    container.style.cursor = "grab";

    var style = document.createElement("style");
    style.textContent = "#diagram .drag-ignore, #diagram .drag-ignore * { cursor: default; }";
    document.head.appendChild(style);
  }
};
