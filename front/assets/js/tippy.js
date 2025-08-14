import tippy, {roundArrow} from 'tippy.js';

window.tippy = tippy;

export var Tippy = {
  defaultTip: function(target) {
    tippy(target, {
      duration: [150, 50]
    });
  },

  otherDefaultTip: function(target) {
    tippy(target, {
      arrow: roundArrow,
      offset: '0, 10',
      duration: 0,
      animation: 'instant',
      maxWidth: '240px',
      theme: 'default-tip'
    });
  },

  permissionsTip: function(target, source) {
    tippy(target, {
      arrow: true,
      arrowType: 'round',
      trigger: 'click',
      duration: [100, 50],
      html: document.querySelector(source),
      theme: 'semaphore',
      placement: 'bottom',
      interactive: true,
      maxWidth: '280px'
    })
  },

  defaultDropdown: function(target, placement = 'bottom') {
    return tippy(target, {
      content(reference) {
        const id = reference.getAttribute('data-template');
        const template = document.getElementById(id);
        const value = reference.getAttribute('data-value');

        if(value !== null) {
          return template.innerHTML.replace(/{{VALUE}}/gi, value);
        } else {
          return template.innerHTML;
        }
      },
      popperOptions: {
        strategy: 'fixed'
      },
      allowHTML: true,
      trigger: 'click',
      theme: 'dropdown',
      interactive: true,
      placement: placement,
      appendTo: document.body, // we are using these because pollman is overwriting the whole partial, and dropdown disappears.
      duration: 0,
      onMount(instance) {
        var input = instance.popper.querySelector("input")
        if(input) {
          input.focus()
        }
      }
    });
  },

  colorDropdown: function(target) {
    tippy(target, {
      content(reference) {
        const id = reference.getAttribute('data-template');
        const template = document.getElementById(id);
        const value = reference.getAttribute('data-value');

        if(value !== null) {
          return template.innerHTML.replace(/{{VALUE}}/gi, value);
        } else {
          return template.innerHTML;
        }
      },
      popperOptions: {
        strategy: 'fixed'
      },
      allowHTML: true,
      trigger: 'click',
      theme: 'dropdown-color',
      interactive: true,
      placement: 'bottom',
      offset: [0, 6],
      appendTo: document.body, // we are using these because pollman is overwriting the whole partial, and dropdown disappears.
      duration: 0
    });
  }
}
