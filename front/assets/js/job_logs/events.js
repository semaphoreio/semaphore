import _ from "lodash";

let running = true;
let items = [];

export var Events = {
  //
  // Returns the module to its initial state.
  //
  // Both `running` and `items` are module level, so under Turbo Drive they
  // survive the visit. Without this, arriving at a second job page would
  // inherit `running == false` from the previous finished job, and Render.tick
  // would exit immediately and never draw a line.
  //
  reset() {
    running = true
    items = []
  },

  stop() {
    running = false
  },

  isRunning() {
    return running
  },

  addItem(item) {
    items.push(item)
  },

  addItems(newItems) {
    items = items.concat(newItems)
  },

  size() {
    return items.length
  },

  notEmpty() {
    return items.length > 0
  },

  getItem() {
    return items.shift()
  },

  clear() {
    items = []
  },

  getItems(count) {
    let buffor

    buffor = _.take(items, count)
    items = _.drop(items, count)

    return buffor
  },

  getAllItems() {
    let toReturn = items;
    items = [];
    return toReturn;
  }
}
