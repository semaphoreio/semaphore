import * as toolbox from "js/toolbox";
import moment from "moment";

export enum PlanType {
  Undefined = `undefined`,
  Grandfathered = `grandfathered`,
  Prepaid = `prepaid`,
  Postpaid = `postpaid`,
  Flat = `flat`,
}

export const parsePlanType = (type: string) => {
  switch(type) {
    case `grandfathered`:
      return PlanType.Grandfathered;
    case `prepaid`:
      return PlanType.Prepaid;
    case `postpaid`:
      return PlanType.Postpaid;
    case `flat`:
      return PlanType.Flat;
    default:
      return PlanType.Undefined;
  }
};

export class Plan {
  id: string;
  name: string;
  slug: string;
  details: PlanDetail[];
  type: PlanType;
  subscriptionEndsOn?: Date;
  subscriptionStartsOn?: Date;
  flags: string[];
  suspensions: string[];
  description: string;
  paymentMethodUrl: string;

  static fromJSON(json: any): Plan {
    const plan = new Plan();
    plan.name = json.display_name as string;
    plan.slug = json.slug as string;
    plan.details = json.details.map((d: any) => PlanDetail.fromJSON(d));
    plan.type = parsePlanType(json.charging_type as string);
    plan.flags = json.flags as string[];
    plan.suspensions = json.suspensions as string[];
    plan.description = json.description as string;
    plan.paymentMethodUrl = json.payment_method_url as string;

    if(json.subscription_starts_on) {
      plan.subscriptionStartsOn = toolbox.Formatter.parseDateToUTC(json.subscription_starts_on as string);
    }
    if(json.subscription_ends_on) {
      plan.subscriptionEndsOn = toolbox.Formatter.parseDateToUTC(json.subscription_ends_on as string);
    }

    return plan;
  }

  requiresCreditCard(): boolean {
    return this.type == PlanType.Postpaid;
  }

  isClassicPlan(): boolean {
    return this.slug.startsWith(`classic-`);
  }

  isOpenSource(): boolean {
    return this.name == `Open Source`;
  }

  isFree(): boolean {
    return this.name == `Free`;
  }

  isStandard(): boolean {
    return this.name == `Standard`;
  }

  didCreditsRunOut(): boolean {
    return this.suspensions.includes(`no_credits`);
  }

  eligibleForStartupPlan(): boolean {
    return this.isFree() || this.isStandard();
  }

  withPaymentDetails(): boolean {
    return !this.flags.includes(`not_charged`);
  }

  withCreditsPage(): boolean {
    return this.type == PlanType.Prepaid;
  }

  isTrial(): boolean {
    return this.flags.includes(`trial`);
  }

  isFlat(): boolean {
    return this.type == PlanType.Flat;
  }

  isTrialEligible(): boolean {
    return this.flags.includes(`eligible_for_trial`);
  }

  isTrialExpired(): boolean {
    return this.flags.includes(`trial`) && this.subscriptionDaysRemaining() <= 0;
  }

  noPaymentMethod(): boolean {
    return this.suspensions.includes(`no_payment_method`);
  }

  paymentFailed(): boolean {
    return this.suspensions.includes(`payement_failed`);
  }

  areCreditsTransferable(): boolean {
    return this.flags.includes(`transferable_credits`);
  }

  hasDescription(): boolean {
    return this.description !== ``;
  }

  hasDetails(): boolean {
    return this.details.length > 0;
  }

  hasPaymentMethodUrl(): boolean {
    return this.paymentMethodUrl !== ``;
  }

  subscriptionDaysRemaining(): number {
    return moment(this.subscriptionEndsOn).diff(moment({ hours: 0 }), `days`);
  }

  expiresIn(): string {
    const days = this.subscriptionDaysRemaining();
    if (days <= 0) {
      return `Trial expired`;
    } else {
      return toolbox.Pluralize(days, `day`, `days`);
    }
  }
}

export class PlanDetail {
  name: string;
  value: string;
  description: string;

  static fromJSON(json: any): PlanDetail {
    const pd = new PlanDetail();

    pd.name = json.display_name as string,
    pd.value = json.display_value as string,
    pd.description = json.display_description as string;

    return pd;
  }
}
