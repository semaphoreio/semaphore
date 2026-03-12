export class Plan {
  name: string;
  type: string;
  description: string;
  contactRequired: boolean;

  static fromJSON(json: any): Plan {
    const p = new Plan();

    p.name = json.name as string;
    p.type = json.type as string;
    p.description = json.description as string;
    p.contactRequired = json.contact_required as boolean;

    return p;
  }
}
