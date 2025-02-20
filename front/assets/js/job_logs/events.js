import _ from "lodash";

let running = true;
let items = [];

export var Events = {
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
