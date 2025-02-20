type featureState = `disabled` | `enabled` | `zero`;

export class FeatureProvider {
  features: Map<string, featureState> = new Map();

  static fromJSON(json: any): FeatureProvider {
    const featureProvider = new FeatureProvider();

    for (const feature in json) {
      featureProvider.features.set(feature, json[feature] as featureState);
    }

    return featureProvider;
  }

  is(feature: string, state: featureState): boolean {
    return (this.features.get(feature) ?? `disabled`) === state;
  }
}
