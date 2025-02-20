export class Features {
  static init(features) {
    this._features = features
  }

  static clear() {
    this._features = {}
  }

  static setFeature(feature, value) {
    this._features = this._features || {}
    this._features[feature] = value
  }

  static isEnabled(feature) {
    return (this._features && this._features[feature]) || false
  }
}