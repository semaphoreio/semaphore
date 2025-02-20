// Creates a props object with overridden toString function. toString returns an attributes
// string in the format: `key1="value1" key2="value2"` for easy use in an HTML string.
export class Props {
  constructor(index, selectedIndex, baseClass, moreClasess = "") {
    this.id = `${baseClass}-result-${index}`
    this.class = `${baseClass}-result ${moreClasess}`
    this['data-result-index'] = index
    this.role = 'option'
    if (index === selectedIndex) {
      this['aria-selected'] = 'true'
    }
  }

  toString() {
    return Object.keys(this).reduce(
      (str, key) => `${str} ${key}="${this[key]}"`,
      ''
    )
  }
}
