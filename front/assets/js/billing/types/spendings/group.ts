import { DailySpending } from "./spending";
import * as metric from "../metric";
import { Formatter } from "js/toolbox";


export enum GroupType {
  Unspecified = `unspecified`,
  MachineTime = `machine_time`,
  Storage = `storage`,
  Seat = `seat`,
  Addon = `addon`,
  MachineCapacity = `machine_capacity`,
}

export const CAPACITY_GROUPS = [GroupType.MachineCapacity];
export const TRENDLESS_GROUPS = [GroupType.Seat, GroupType.MachineCapacity];
export const USAGELESS_GROUPS = [GroupType.Addon, GroupType.Storage, GroupType.MachineCapacity];

export class Group {
  type: GroupType;
  price: string;
  items: Item[];
  dailySpendings: DailySpending[];
  trends: Trend[];

  static fromJSON(json: any): Group {
    const g = new Group();

    g.type = parseGroupType(json.type as string);
    g.price = json.total_price as string;
    g.items = json.items.map(Item.fromJSON);
    g.dailySpendings = [];
    g.trends = json.trends.map(Trend.fromJSON);

    return g;
  }

  get rawPrice(): number {
    return Formatter.parseMoney(this.price);
  }

  get priceTrend(): string {
    if(this.trends.length == 0) {
      return `new`;
    } else {
      const lastPrice = Formatter.parseMoney(this.trends[0].price);
      const currentPrice = Formatter.parseMoney(this.price);
      if(lastPrice > currentPrice) {
        return `down`;
      } else if(lastPrice < currentPrice) {
        return `up`;
      } else if (lastPrice == currentPrice){
        return `same`;
      }
    }
  }

  get usageTrend(): string {
    if(this.trends.length == 0) {
      return `new`;
    } else {
      const lastUsage = this.trends[0].usage;
      if(lastUsage > this.usage) {
        return `down`;
      } else if(lastUsage < this.usage) {
        return `up`;
      } else if (lastUsage == this.usage){
        return `same`;
      }
    }
  }

  static get Empty(): Group {
    const group = new Group();
    group.type = GroupType.Unspecified;
    group.price = `$ 0.00`;
    group.items = [];
    group.dailySpendings = [];
    group.trends = [];
    return group;
  }

  static hexColor(type: GroupType): string {
    switch (type) {
      case GroupType.MachineTime:
        return `#2196F3`;
      case GroupType.Seat:
        return `#8658d6`;
      case GroupType.Storage:
        return `#fd7e14`;
      case GroupType.Addon:
        return `#00a569`;
      case GroupType.MachineCapacity:
        return `#2196F3`;
      default:
        return Formatter.colorFromName(type);
    }
  }

  get name(): string {
    switch (this.type) {
      case GroupType.MachineTime:
        return `Machine Time`;
      case GroupType.Seat:
        return `Seats`;
      case GroupType.Storage:
        return `Storage & Egress`;
      case GroupType.Addon:
        return `Add-ons`;
      case GroupType.MachineCapacity:
        return `Machine Capacity`;
      default:
        return ``;
    }
  }

  get iconName(): string {
    switch (this.type) {
      case GroupType.MachineTime:
        return `dns`;
      case GroupType.Seat:
        return `group`;
      case GroupType.Storage:
        return `cloud_download`;
      case GroupType.Addon:
        return `auto_awesome`;
      case GroupType.MachineCapacity:
        return `dns`;
      default:
        return ``;
    }
  }

  get priceLabel(): string {
    switch (this.type) {
      case GroupType.MachineTime:
        return `Price ($/min)`;
      case GroupType.Seat:
        return `Price ($/seat)`;
      case GroupType.Storage:
        return `Price ($/GB)`;
      case GroupType.Addon:
        return `Price ($/item)`;
      default:
        return `Price`;
    }
  }

  get usage(): number {
    return this.items.reduce((sum, item) => sum + item.usage, 0);
  }

  get usageLabel(): string {
    switch (this.type) {
      case GroupType.MachineTime:
        return `Usage (min)`;
      case GroupType.Storage:
        return `Usage (GB)`;
      case GroupType.Addon:
        return `Qty.`;
      case GroupType.MachineCapacity:
        return `Capacity`;
      default:
        return `Usage`;
    }
  }


  get dailyMetrics(): metric.Interface[] {
    return this.dailySpendings.map((spending) => {
      return {
        name: this.name,
        value: spending.price,
        date: spending.day,
        isEmpty: () => false,
      } as metric.Interface;
    });

  }

  get upToDayMetrics(): metric.Interface[] {
    return this.dailySpendings.map((spending) => {
      return {
        name: this.name,
        value: spending.priceUpToDay,
        date: spending.day,
        isEmpty: () => false,
      } as metric.Interface;
    });
  }

  isCapacityBased(): boolean {
    if (CAPACITY_GROUPS.includes(this.type)) {
      return true;
    } else {
      return false;
    }
  }

  get showTrends(): boolean {
    if (TRENDLESS_GROUPS.includes(this.type)) {
      return false;
    } else {
      return this.items.length > 1;
    }
  }

  get showUsage(): boolean {
    if (USAGELESS_GROUPS.includes(this.type)) {
      return false;
    } else {
      return true;
    }
  }
}

export const parseGroupType = (type: string): GroupType => {
  switch (type) {
    case `machine_time`:
      return GroupType.MachineTime;
    case `seats`:
      return GroupType.Seat;
    case `storage`:
      return GroupType.Storage;
    case `addons`:
      return GroupType.Addon;
    case `machine_capacity`:
      return GroupType.MachineCapacity;
    default:
      return GroupType.Unspecified;
  }
};

export class Trend {
  name: string;
  usage: number;
  price: string;

  static fromJSON(json: any): Trend {
    const t = new Trend();

    t.name = json.name as string;
    t.usage = json.usage as number;
    t.price = json.price as string;

    return t;
  }
}

export class Item {
  description: string;
  type: string;
  name: string;
  price: string;
  unitPrice: string;
  usage: number;
  tiers: Item[];
  trends: Trend[];

  static fromJSON(json: any): Item {
    const i = new Item();

    i.description = json.display_description as string;
    i.type = json.name as string;
    i.name = json.display_name as string;
    i.trends = json.trends.map(Trend.fromJSON);
    i.price = json.total_price as string;
    i.unitPrice = json.unit_price as string;
    i.usage = json.units as number;
    i.tiers = json.tiers.map(Item.fromJSON);

    return i;
  }

  get hasPriceTrends(): boolean {
    const priceTrends = this.trends.filter((trend) => {
      return trend.price != ``;
    });

    return priceTrends.length > 0;
  }

  get hasTiers(): boolean {
    return this.tiers.length > 0;
  }

  get priceTrend(): string {
    if(this.trends.length == 0) {
      return `new`;
    } else {
      const lastPrice = Formatter.parseMoney(this.trends[0].price);
      const currentPrice = Formatter.parseMoney(this.price);
      if(lastPrice > currentPrice) {
        return `down`;
      } else if(lastPrice < currentPrice) {
        return `up`;
      } else if (lastPrice == currentPrice){
        return `same`;
      }
    }
  }

  get usageTrend(): string {
    if(this.trends.length == 0) {
      return `new`;
    } else {
      const lastUsage = this.trends[0].usage;
      if(lastUsage > this.usage) {
        return `down`;
      } else if(lastUsage < this.usage) {
        return `up`;
      } else if (lastUsage == this.usage){
        return `same`;
      }
    }
  }

  get rawPrice(): number {
    return Formatter.parseMoney(this.price);
  }

  get rawUnitPrice(): number {
    return Formatter.parseMoney(this.unitPrice);
  }
}
