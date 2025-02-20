let state = {};

export var State = {
  init(initState) {
    state = initState
  },

  get(key) {
    return state[key]
  },

  set(key, value) {
    state[key] = value
    this.afterChange()
  },

  onUpdate(callback) {
    this.callback = callback
  },

  afterChange() {
    if(this.callback !== null && this.callback !== undefined) {
      this.callback()
    }
  }
}
