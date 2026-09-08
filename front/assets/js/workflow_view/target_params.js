import TomSelect from 'tom-select'

export var TargetParams = {
    init: function (selector = null) {
        document.querySelectorAll(selector).forEach((element) => {
            if (!element.tomselect) {
                new TomSelect(element, {
                    hidePlaceholder: true,
                    plugins: ['no_backspace_delete'],
                    onInitialize: function () {
                        TargetParams.preventScrollOnFocus(this)
                    },
                })
            }
        })
    },

    preventScrollOnFocus: function (tomselect) {
        const focusNode = tomselect.focus_node

        if (!focusNode || focusNode.preventScrollOnFocus) {
            return
        }

        const focus = focusNode.focus
        focusNode.focus = function (options = {}) {
            focus.call(this, Object.assign({}, options, { preventScroll: true }))
        }
        focusNode.preventScrollOnFocus = true
    }
}
