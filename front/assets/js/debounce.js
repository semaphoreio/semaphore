// Source: https://github.com/trevoreyre/autocomplete/blob/b391c463dbe96d7817ca89338677aee450a20974/packages/autocomplete/util/debounce.js

// Returns a function, that, as long as it continues to be invoked, will not
// be triggered. The function will be called after it stops being called for
// N milliseconds. If `immediate` is passed, trigger the function on the
// leading edge, instead of the trailing.
const debounce = (func, wait, immediate) => {
  let timeout

  return function executedFunction() {
    const context = this
    const args = arguments

    const later = function() {
      timeout = null
      if (!immediate) func.apply(context, args)
    }

    const callNow = immediate && !timeout
    clearTimeout(timeout)
    timeout = setTimeout(later, wait)

    if (callNow) func.apply(context, args)
  }
}

export default debounce
