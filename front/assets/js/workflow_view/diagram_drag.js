export var DiagramDrag = {
  init: function () {
    var container = document.getElementById("diagram");
    if (!container) return;

    var state = { active: false, startX: 0, scrollLeft: 0 };

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
      state.scrollLeft = container.scrollLeft;
      container.style.cursor = "grabbing";
      container.style.userSelect = "none";
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
    });

    window.addEventListener("mouseup", function () {
      if (!state.active) return;
      state.active = false;
      container.style.cursor = "grab";
      container.style.userSelect = "";
    });

    container.style.cursor = "grab";
  }
};
