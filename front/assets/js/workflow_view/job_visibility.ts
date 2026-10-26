export type JobVisibility = `all` | `current`;

export interface JobCounts {
  currentRun: number;
  reused: number;
  skipped: number;
}

// Polling replaces pipeline fragments, so keep choices for the lifetime of the page.
const visibilityByPipeline = new Map<string, JobVisibility>();

export function getJobVisibility(pipelineId: string): JobVisibility {
  return visibilityByPipeline.get(pipelineId) ?? `all`;
}

export function setJobVisibility(pipelineId: string, visibility: JobVisibility): void {
  visibilityByPipeline.set(pipelineId, visibility);
}

export function resetJobVisibility(): void {
  visibilityByPipeline.clear();
}

export function filterReusedJobs(html: string, visibility: JobVisibility): string {
  if (visibility === `all`) return html;

  const template = document.createElement(`template`);
  template.innerHTML = html;
  // The server applies this class using both job and block lineage.
  const reused = template.content.querySelectorAll(`.job-reused`);
  if (reused.length === 0) return html;

  reused.forEach(row => row.remove());
  const summary = document.createElement(`div`);
  summary.className = `f6 gray pv1 bt b--black-15`;
  summary.textContent = `${reused.length} reused ${reused.length === 1 ? `job` : `jobs`} hidden`;
  template.content.firstElementChild.appendChild(summary);
  return template.innerHTML;
}
