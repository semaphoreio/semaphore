import $ from "jquery";

export class Utils {
  //
  // Finds an attribute on a DOM element, reads the value, and converts it to
  // an integer.
  //
  static intAttr(selector, name) {
    return parseInt($(selector).attr(name), 10)
  }

  static dompath(element) {
    var path = '',
    i, innerText, tag, selector, classes;

    for (i = 0; element && element.nodeType == 1; element = element.parentNode, i++) {
        innerText = element.childNodes.length === 0 ? element.innerHTML : '';
        tag = element.tagName.toLowerCase();
        classes = element.className;

        // Skip <html> and <body> tags
        if (tag === "html" || tag === "body")
            continue;

        if (element.id !== '') {
            // If element has an ID, use only the ID of the element
            selector = '#' + element.id;

            // To use this with jQuery, return a path once we have an ID
            // as it's no need to look for more parents afterwards.
            //return selector + ' ' + path;
        } else if (classes.length > 0) {
            // If element has classes, use the element tag with the class names appended
            selector = tag + '.' + classes.replace(/ /g , ".");
        } else {
            // If element has neither, print tag with containing text appended (if any)
            selector = tag + ((innerText.length > 0) ? ":contains('" + innerText + "')" : "");
        }

        path = ' ' + selector + path;
    }
    return path;
	}

  static preserveSelectedElement(cb) {
		let hasActiveElement = false
    let activeElementDomPath = ''
    let selectionStart = 0
    let selectionEnd = 0

    let activeElement = document.activeElement

    if((activeElement.tagName == "INPUT" && activeElement.type == "text") || activeElement.tagName == "TEXTAREA") {
      hasActiveElement = true
      activeElementDomPath = Utils.dompath(activeElement)
      selectionStart = activeElement.selectionStart
      selectionEnd = activeElement.selectionEnd
    }

    cb()

    if(hasActiveElement) {
      let el = $(activeElementDomPath)

      el.focus()

      el[0].selectionStart = selectionStart
      el[0].selectionEnd = selectionEnd
    }
  }

  static preserveDropdownState(selector, cb) {
    let openedDetails = []

    // save which details are open
    $(selector).find("details").each(function() {
      openedDetails.push($(this)[0].hasAttribute("open"))
    })

    cb()

    // then, re-open after new render
    $(selector).find("details").each(function(index) {
      if(openedDetails[index]) {
        $(this).attr("open", "")
      }
    })
  }

  static preserveScrollPositions(selector, cb) {
    let oldTop  = $(selector).scrollTop()
    let oldLeft = $(selector).scrollLeft()

    cb()

    $(selector).scrollTop(oldTop)
    $(selector).scrollLeft(oldLeft)
  }
}
