export enum GroupType {
  Unspecified = `unspecified`,
  Exclusive = `exclusive`,
  Regular = `regular`,
}

export class Addon {
  name: string;
  displayName: string;
  description: string;
  price: string;
  enabled: boolean;
  modifiable: boolean;

  static fromJSON(json: any): Addon {
    const addon = new Addon();
    addon.name = json.name as string;
    addon.displayName = json.display_name as string;
    addon.description = json.description as string;
    addon.price = json.price as string;
    addon.enabled = json.enabled as boolean;
    addon.modifiable = json.modifiable as boolean;
    return addon;
  }
}

export class AddonGroup {
  name: string;
  displayName: string;
  description: string;
  type: GroupType;
  addons: Addon[];

  static fromJSON(json: any): AddonGroup {
    const group = new AddonGroup();
    group.name = json.name as string;
    group.displayName = json.display_name as string;
    group.description = json.description as string;
    group.type = parseType(json.type as string);
    group.addons = (json.addons || []).map(Addon.fromJSON);
    return group;
  }
}

const parseType = (type: string): GroupType => {
  switch (type) {
    case `exclusive`:
      return GroupType.Exclusive;
    case `regular`:
      return GroupType.Regular;
    default:
      return GroupType.Unspecified;
  }
};
