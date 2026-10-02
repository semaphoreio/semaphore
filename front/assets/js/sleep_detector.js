export var SleepDetector = {
  init: function(callback) {
    // Drop the interval from a previous page before starting another one.
    this.stop()

    this.callback = callback
    this.lastTime = this.getTime()

    this.tick()
  },

  stop: function() {
    if (this.ticker) {
      clearInterval(this.ticker)
      this.ticker = null
    }
  },

  tick: function() {
    this.ticker = setInterval(function() {
      var currentTime = this.getTime()

      if(this.justWokeUp()) {
        setTimeout(function() {
          this.callback()
        }.bind(this), 2000);
      }

      this.lastTime = this.getTime()
    }.bind(this), 2000);
  },

  justWokeUp: function() {
    var currentTime = this.getTime()

    return currentTime > (this.lastTime + 2000*3) // ignore small delays
  },

  getTime: function() {
    return (new Date()).getTime()
  }
}
