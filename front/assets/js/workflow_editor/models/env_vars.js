export class EnvVars {
  constructor(parent, structure) {
    this.parent = parent // can be block or container agent
    this.vars = structure || []
  }

  count() {
    return this.vars.length
  }

  isEmpty() {
    return this.vars.length === 0
  }

  map(fun) {
    return this.vars.map(fun)
  }

  addNew() {
    this.vars.push({
      name: "FOO_" + (this.vars.length + 1),
      value: "BAR_" + (this.vars.length + 1)
    })

    this.afterUpdate()
  }

  change(index, name, value) {
    this.vars[index].name = name
    this.vars[index].value = value

    this.afterUpdate()
  }

  remove(index) {
    this.vars.splice(index, 1)
    this.afterUpdate()
  }

  toJson() {
    return this.vars
  }

  afterUpdate() {
    this.parent.afterUpdate()
  }
}
