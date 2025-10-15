export class Plan {
  name: string;
  type: string;
  description: string;
  contactRequired: boolean;
  features: Features;

  static fromJSON(json: any): Plan {
    const p = new Plan();

    p.name = json.name as string;
    p.type = json.type as string;
    p.description = json.description as string;
    p.contactRequired = json.contact_required as boolean;
    p.features = Features.fromJSON(json.features);

    return p;
  }
}

export class Features {
  parallelism: number;
  maxUsers: number;
  maxSelfHostedAgents: number;
  cloudMinutes: number;

  seatCost: number;

  largeResourceTypes: boolean;
  prioritySupport: boolean;

  static fromJSON(json: any): Features {
    const f = new Features();

    f.parallelism = numberOrInfinity(json.parallelism as number);
    f.maxUsers = numberOrInfinity(json.max_users as number);
    f.maxSelfHostedAgents = numberOrInfinity(
      json.max_self_hosted_agents as number,
    );
    f.cloudMinutes = numberOrInfinity(json.cloud_minutes as number);

    f.seatCost = json.seat_cost as number;

    f.largeResourceTypes = json.large_resource_types as boolean;
    f.prioritySupport = json.priority_support as boolean;

    return f;
  }
}

function numberOrInfinity(value: number): number {
  return value == -1 ? Number.POSITIVE_INFINITY : value;
}
