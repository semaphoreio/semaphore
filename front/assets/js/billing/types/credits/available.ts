import moment from "moment";

export enum CreditType {
  Undefined = `undefined`,
  Prepaid = `prepaid`,
  Gift = `gift`,
  Subscription = `subscription`,
  Educational = `educational`
}

export class Available {
  amount: string;
  type: CreditType;
  givenAt: Date;
  expiresAt: Date;

  static fromJSON(json: any): Available {
    const a = new Available();

    a.type = parseType(json.type as string);
    a.amount = json.amount as string;
    a.givenAt = moment(json.given_at as string).toDate();
    a.expiresAt = moment(json.expires_at as string).toDate();

    return a;
  }

  get typeName(): string {
    switch(this.type) {
      case CreditType.Prepaid:
        return `Credits bought`;
      case CreditType.Gift:
        return `Gift credits`;
      case CreditType.Subscription:
        return `Subscription credits`;
      case CreditType.Educational:
        return `Educational credits`;
      default:
        return ``;
    }
  }

}

export const parseType = (type: string): CreditType => {
  switch(type) {
    case `prepaid`:
      return CreditType.Prepaid;
    case `gift`:
      return CreditType.Gift;
    case `subscription`:
      return CreditType.Subscription;
    case `educational`:
      return CreditType.Educational;
    default:
      return CreditType.Undefined;
  }
};
