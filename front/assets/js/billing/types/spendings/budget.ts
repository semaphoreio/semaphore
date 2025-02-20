export class Budget {
  email: string;
  limit: string;
  defaultEmail: string;

  static fromJSON(json: any): Budget {
    const b = new Budget();

    b.email = json.email as string;
    b.limit = json.limit as string;
    b.defaultEmail = json.default_email as string;
    return b;
  }

  static Zero(): Budget {
    const b = new Budget();
    b.email = ``;
    b.limit = `$0.00`;
    b.defaultEmail = ``;
    return b;
  }

  hasLimit(): boolean {
    return ![``, `$0.00`].includes(this.limit);
  }
}
