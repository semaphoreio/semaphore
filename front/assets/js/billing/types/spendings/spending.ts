import moment from "moment";
import { Group, GroupType, parseGroupType, Item } from "./group";
import { Plan, PlanType } from "./plan";
import { Formatter } from "js/toolbox";

export enum SpendingLayout {
  Regular,
  Compact,
  UpdatePayment,
  Classic,
}

export class Spending {
  id: string;
  name: string;
  from: Date;
  to: Date;
  plan: Plan;
  summary: Summary;
  groups: Group[];

  static fromJSON(json: any): Spending {
    const s = new Spending();
    const fromDate = moment
      .utc(json.from as string)
      .startOf(`day`)
      .format(`YYYY-MM-DD`);
    const toDate = moment
      .utc(json.to as string)
      .startOf(`day`)
      .format(`YYYY-MM-DD`);

    s.id = json.id as string;
    s.name = json.display_name as string;
    s.from = Formatter.parseDateToUTC(fromDate);
    s.to = Formatter.parseDateToUTC(toDate);
    s.plan = Plan.fromJSON(json.plan);
    s.summary = Summary.fromJSON(json.summary);
    s.groups = json.groups.map(Group.fromJSON) as Group[];

    const machineCapacityGroup = s.getGroup(GroupType.MachineCapacity);
    if (machineCapacityGroup) {
      machineCapacityGroup.price = s.summary.subscriptionTotal;
    }

    return s;
  }

  get layout(): SpendingLayout {
    if (this.id == ``) {
      return SpendingLayout.UpdatePayment;
    }

    if (this.plan.isClassicPlan()) {
      return SpendingLayout.Classic;
    }

    if ([PlanType.Grandfathered, PlanType.Flat].includes(this.plan.type)) {
      return SpendingLayout.Compact;
    }

    return SpendingLayout.Regular;
  }

  getGroup(type: GroupType): Group {
    const group = this.groups.find((g) => g.type === type);

    if (group) {
      return group;
    } else {
      return Group.Empty;
    }
  }
}

export enum Discount {
  None = `0`,
}

export class Summary {
  creditsStarting: string;
  creditsTotal: string;
  creditsUsed: string;
  subscriptionTotal: string;
  totalBill: string;
  usageTotal: string;
  usageUsed: string;
  discount: string;
  discountAmount: string;

  static fromJSON(json: any): Summary {
    const ss = new Summary();

    ss.creditsStarting = json.credits_starting as string;
    ss.creditsTotal = json.credits_total as string;
    ss.creditsUsed = json.credits_used as string;
    ss.subscriptionTotal = json.subscription_total as string;
    ss.totalBill = json.total_bill as string;
    ss.usageTotal = json.usage_total as string;
    ss.usageUsed = json.usage_used as string;
    ss.discount = json.discount as string;
    ss.discountAmount = json.discount_amount as string;

    return ss;
  }

  hasStartingCredits(): boolean {
    return this.creditsStarting !== `$0.00`;
  }

  hasSubscription(): boolean {
    return this.subscriptionTotal !== `$0.00`;
  }
}

export class DailySpending {
  type: GroupType;
  day: Date;
  price: number;
  priceUpToDay: number;
  items: Item[];

  static fromJSON(json: any): DailySpending {
    const du = new DailySpending();

    du.type = parseGroupType(json.type as string);
    du.day = Formatter.parseDateToUTC(json.day as string);
    du.price = Formatter.parseMoney(json.price_for_the_day as string);
    du.priceUpToDay = Formatter.parseMoney(json.price_up_to_the_day as string);
    du.items = json.items.map(Item.fromJSON) as Item[];

    return du;
  }
}
