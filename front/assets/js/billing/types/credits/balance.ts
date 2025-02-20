import moment from "moment";

export enum BalanceType {
  Undefined = `undefined`,
  Charge = `charge`,
  Deposit = `deposit`,
}

export class Balance {
  amount: string;
  type: BalanceType;
  occuredAt: Date;
  description: string;

  static fromJSON(json: any): Balance {
    const u = new Balance();

    u.type = parseType(json.type as string);
    u.amount = json.amount as string;
    u.occuredAt = moment(json.occured_at as string).toDate();
    u.description = json.description as string;

    return u;
  }

}

export const parseType = (type: string): BalanceType => {
  switch(type) {
    case `charge`:
      return BalanceType.Charge;
    case `deposit`:
      return BalanceType.Deposit;
    default:
      return BalanceType.Undefined;
  }
};
