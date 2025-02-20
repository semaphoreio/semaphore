import TomSelect from 'tom-select'

export var TargetParams = {
    init: function () {
        document.querySelectorAll('[data-promotion-param-name]').forEach((element) => {
            if (!element.tomselect) {
                new TomSelect(element, {
                    hidePlaceholder: true,
                    plugins: ['no_backspace_delete', 'dropdown_input'],
                })
            }
        })
    }
}