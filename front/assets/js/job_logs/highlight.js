import { Scroll } from "./scroll"
import { FoldToggle } from "./fold_toggle"

let highlighted = false
let last_selected_line = null

export var Highlight = {
  init(containerSelector) {
    const container = document.querySelector(containerSelector)
    const config = { childList: true, subtree: true }

    const callback = function(mutationsList, observer) {
      for(let mutation of mutationsList) {
        if (mutation.type === 'childList') {
          if (mutation.addedNodes.length > 0) {
            if(highlighted == false) {
              this.highlightLines()
            }
          }
        }
      }
    }.bind(this);

    const observer = new MutationObserver(callback);

    observer.observe(container, config);
  },

  highlightLines() {
    this.clearHighlight()

    let selected = this.getSelectedLines();
    if(selected) {
      this.last_selected_line = selected.first;

      let allLines, fold
      allLines = Array.from(document.querySelector("#job-log-container").querySelectorAll('.job-log-line'))

      let elements = allLines.slice(selected.first - 1, selected.last);
      if (elements.length) {
        elements.forEach((el) => {
          el.classList.add("highlight")

          fold = el.closest(".job-log-fold")
          if(!el.classList.contains("command")) {
            FoldToggle.open(fold)
          }
        })

        let container = document.querySelector("#job-log-container")
        Scroll.to(container, elements[0])

        if(selected.count == elements.length) {
          this.highlighted = true
        }
      }
    }
  },

  highlightLine(line, multiline = false) {
    let selected = this.getSelectedLines();

    let allLines = Array.from(document.querySelector("#job-log-container").querySelectorAll('.job-log-line'))
    let lineNumber = allLines.indexOf(line) + 1
    let hash

    if (selected !== undefined && selected.first == lineNumber && selected.count == 1) {
      history.replaceState(null, "", ' ');
    } else if (multiline && (this.last_selected_line != null)) {
      let d;
      d = [lineNumber, this.last_selected_line].sort((a, b) => a - b);
      window.location.hash = `#L${d[0]}-L${d[1]}`;
    } else {
      window.location.hash = `#L${lineNumber}`;
    }

    this.highlightLines()
  },

  clearHighlight() {
    Array.from(document.querySelector("#job-log-container").querySelectorAll('.job-log-line.highlight')).forEach((el) => {
      el.classList.remove('highlight')
    })
  },

  getSelectedLines() {
    let match = window.location.hash.match(/#L(\d+)(-L(\d+))?$/);
    if (match) {
      let first = match[1];
      let last = match[3] || match[1];
      return {
        first: first,
        last: last,
        count: last - first + 1
      };
    }
  }
}
