import _ from "lodash"

import { Errors } from "./errors"

class Secret {
  constructor(structure) {
    this.structure = structure || {}
    this.errors = new Errors()
  }

  name() {
    return this.structure.name
  }

  validate() {
    this.errors.reset()

    if(!Secrets.validSecretNames().includes(this.name())) {
      this.errors.add("name", "Secret is not available for this project or does not exist in the organization")
    }
  }

  toJson() {
    return _.cloneDeep(this.structure)
  }

  usedSecretTemplate(index) {
    if (this.errors.exists()) {
      let errorMessage = this.errors.list("name").join(", ")

      return `<div>
        <p class="f6 mb0 red">${errorMessage}</p>
        <input autocomplete="off" data-action=toggleBlockSecret data-secret-name="${escapeHtml(this.name())}" type="checkbox" id="secret-${index}" class="mr1" checked="">
        <label class="red" data-secret-name="${escapeHtml(this.name())}" for="secret-${index}">${escapeHtml(this.name())}</label>
      </div>`;
    } else {
      return `<div>
        <input autocomplete="off" data-action=toggleBlockSecret data-secret-name="${escapeHtml(this.name())}" type="checkbox" id="secret-${index}" class="mr1" checked="">
        <label data-secret-name="${escapeHtml(this.name())}" for="secret-${index}">${escapeHtml(this.name())}</label>
      </div>`;
    }
  }
}

export class Secrets {
  static setValidSecretNames(validOrgSecretNames, validProjectSecretNames) {
    this._validSecretNames = _.sortedUniq(_.concat(validOrgSecretNames, validProjectSecretNames).sort())
  }

  static validSecretNames() {
    return this._validSecretNames || []
  }

  constructor(parent, structure) {
    this.parent = parent // can be block or pipeline globcal config
    this.secrets = (structure || []).map((s) => new Secret(s))
    this.errors = new Errors()
  }

  allSecretNames() {
    let allSecretsInOrg = _.cloneDeep(Secrets.validSecretNames())
    let allSecretsOnBlock = this.secrets.map((s) => s.name())

    let allSecrets = _.concat(allSecretsInOrg, allSecretsOnBlock).sort()

    return _.sortedUniq(allSecrets)
  }

  isEmpty() {
    return this.secrets.length === 0
  }

  validate() {
    this.errors.reset()

    this.secrets.forEach((s) => {
      s.validate()

      if(s.errors.exists()) {
        this.errors.addNested(s.name, s.errors)
      }
    })
  }

  map(fun) {
    return this.secrets.map(fun)
  }

  filter(fun) {
    return this.secrets.filter(fun)
  }

  includes(name) {
    let index = this.secrets.findIndex((s) => s.name() === name)

    return index >= 0
  }

  add(name) {
    if(this.includes(name)) {
      // we don't want duplicate entries
      return
    }

    let s = new Secret({name: name})

    this.secrets.push(s)

    // keep the secrets sorted
    this.secrets.sort((a, b) => {
      return a.name() > b.name() ? 1 : -1;
    })

    this.afterUpdate()
  }

  remove(name) {
    let index = this.secrets.findIndex((s) => s.name() === name)

    if(index >= 0) {
      this.secrets.splice(index, 1)
    } else {
      throw `Secret with name '${name}' not found`
    }

    this.afterUpdate()
  }

  findByName(name) {
    return this.secrets.find((s) => s.name() == name)
  }

  toJson() {
    return this.secrets.map((s) => s.toJson())
  }

  afterUpdate() {
    this.parent.afterUpdate()
  }
}
