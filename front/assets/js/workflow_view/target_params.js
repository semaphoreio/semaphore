import TomSelect from 'tom-select'

export var TargetParams = {
    init: function (selector = null) {
        document.querySelectorAll(selector).forEach((element) => {
            if (!element.tomselect) {
                new TomSelect(element, {
                    hidePlaceholder: true,
                    plugins: ['no_backspace_delete'],
                })
            }
        })
    }
}