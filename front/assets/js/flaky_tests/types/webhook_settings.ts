export class WebhookSettings {
  id = ``;
  org_id: string;
  project_id: string;
  webhook_url: string;
  branches: string[];
  enabled = true;
  greedy = false;

  static fromJSON(json: any): WebhookSettings {
    const ws = new WebhookSettings();
    ws.id = json.id as string;
    ws.org_id = json.org_id as string;
    ws.project_id = json.project_id as string;
    ws.webhook_url = json.webhook_url as string;
    ws.branches = json.branches;
    ws.enabled = json.enabled;
    ws.greedy = json.greedy;

    return ws;
  }
}
