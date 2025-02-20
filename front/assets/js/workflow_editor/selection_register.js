let counter = 1;
let register = {};
let currentSelectionUid = null

// returns an universal global ID for all registered elements
export var SelectionRegister = {
  add(ref) {
    let uid = "u" + counter;

    register[uid] = ref

    counter += 1

    return uid
  },

  remove(uid) {
    delete register[uid];

    if(currentSelectionUid === uid) {
      currentSelectionUid = null;
      this.afterSelectionChange()
    }
  },

  lookup(uid) {
    return register[uid]
  },

  getCurrentSelectionUid() {
    return currentSelectionUid
  },

  getSelectedElement() {
    if(currentSelectionUid !== null) {
      return this.lookup(currentSelectionUid)
    } else {
      return null
    }
  },

  setCurrentSelectionUid(uid) {
    currentSelectionUid = uid

    this.afterSelectionChange()
  },

  onUpdate(callback) {
    this.callback = callback
  },

  afterSelectionChange() {
    if(this.callback !== null && this.callback !== undefined) {
      this.callback()
    }
  }
}
