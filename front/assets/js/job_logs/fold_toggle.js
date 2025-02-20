export var FoldToggle = {
  toggle(fold) {
    fold.classList.toggle("open")
    fold.querySelector('div[cmd-lines-container]').classList.toggle("dn")
  },

  open(fold) {
    fold.classList.add("open")
    fold.querySelector('div[cmd-lines-container]').classList.remove("dn")
  },

  close(fold) {
    fold.classList.remove("open")
    fold.querySelector('div[cmd-lines-container]').classList.add("dn")
  },

  removeArrowIfEmpty(fold) {
    if(fold.querySelectorAll('div:not(.command)').length == 0) {
      fold.classList.remove("open")
      fold.classList.add("empty")
    }
  },

  addArrowIfNotEmpty(fold) {
    if(fold.querySelectorAll('div:not(.command)').length > 0) {
      fold.classList.remove("empty")
    }
  },

  isTogglable(fold) {
    return !fold.classList.contains("empty")
  }
}
