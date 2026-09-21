import $ from "jquery"
import moment from "moment"
import "moment-duration-format"

export var Timer = {
  init: function() {
    // Under Turbo Drive init() runs again on each visit to the workflow view,
    // so drop any previous interval instead of stacking a second ticker.
    this.stop();

    this.ticker = setInterval(this.tick, 1000);
  },

  stop: function() {
    if (this.ticker) {
      clearInterval(this.ticker);
      this.ticker = null;
    }
  },

  tick: function() {
    var timers = document.querySelectorAll("[timer]");

    Array.from(timers).forEach(function(timer) {
      Timer.increment(timer);
      Timer.renderTime(timer)
    });
  },

  increment: function(timer) {
    if (!timer || !timer.hasAttribute("run")) return;

    var current = Number(timer.getAttribute('seconds'));
    timer.setAttribute('seconds', current + 1);
  },

  renderTime: function(timer) {
    var current   = Number(timer.getAttribute('seconds'));
    var duration  = moment.duration(current, 'seconds');
    var formatted = duration.format("hh:mm:ss", {stopTrim: "mm"});

    timer.innerHTML = formatted;
  }
};
