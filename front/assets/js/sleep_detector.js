export var SleepDetector = {
  init: function(callback) {
    this.callback = callback
    this.lastTime = this.getTime()

    this.tick()
  },

  tick: function() {
    setInterval(function() {
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
