import moment from "moment";

type LockType = `progress` | `permission` | `feature`;

export class Learn {
  sections: Section[];
  steps: Step[];
  isGuideCompleted: boolean;
  isGuideSkipped: boolean;
  isGuideFinished: boolean;

  static fromJSON(json: any): Learn {
    const learn = new Learn();

    learn.sections = json.sections.map(Section.fromJSON);
    learn.steps = json.progress.steps.map(Step.fromJSON);
    learn.isGuideCompleted = json.progress.is_completed as boolean;
    learn.isGuideSkipped = json.progress.is_skipped as boolean;
    learn.isGuideFinished = json.progress.is_finished as boolean;

    return learn;
  }
}

export class Section {
  id: string;
  name: string;
  description: string;
  dependsOn: string[];
  tasks: Task[];
  duration: string;
  completed: boolean;
  locked: LockType[];

  static fromJSON(json: any): Section {
    const section = new Section();

    section.id = json.id as string;
    section.name = json.name as string;
    section.description = json.description as string;
    section.dependsOn = json.depends_on as string[];
    section.tasks = json.tasks.map(Task.fromJSON);
    section.completed = json.completed as boolean;
    section.duration = json.duration as string;
    section.locked = json.locked as LockType[];

    return section;
  }

  isCompleted(): boolean {
    return this.completed;
  }

  isFeatureLocked(): boolean {
    return this.locked.includes(`feature`);
  }

  getDefaultTask(): Task {
    return this.tasks.find((task) => !task.isCompleted());
  }

  hasTask(taskId: string): boolean {
    return this.tasks.some((task) => task.id === taskId);
  }
}

export class Task {
  id: string;
  eventId: string;
  name: string;
  description: string;
  completed: boolean;
  completedAt: Date;
  locked: LockType[];

  static fromJSON(json: any): Task {
    const task = new Task();

    task.id = json.id as string;
    task.eventId = json.event_id as string;
    task.name = json.name as string;
    task.description = json.description as string;
    task.completed = json.completed as boolean;
    task.completedAt = moment(json.completed_at as string).toDate();
    task.locked = json.locked as LockType[];

    return task;
  }

  isLocked(): boolean {
    return this.locked.length > 0;
  }

  isCompleted(): boolean {
    return this.completed;
  }

  isSelectable(): boolean {
    return !this.isLocked() || this.isCompleted();
  }
}

export class Step {
  title: string;
  subtitle: string;
  completed: boolean;

  static fromJSON(json: any): Step {
    const step = new Step();

    step.title = json.title as string;
    step.subtitle = json.subtitle as string;
    step.completed = json.completed as boolean;

    return step;
  }
}
