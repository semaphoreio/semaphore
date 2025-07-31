import TomSelect from 'tom-select'

export default {
  init(prefixId) {
    return new TomSelect(`#${prefixId}_secrets`, {
      sortField: { field: "text" },
      plugins: ['no_backspace_delete', 'remove_button'],
      render: { item: renderItem }
    })
  }
}

function renderItem(data, escape) {
  const labelClass = data.disabled ? "red" : ""

  return `
    <div class="item" data-ts-item="">
      <label class="${labelClass}">${escape(data.text)}</span>
    </div>
  `
}
