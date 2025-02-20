import { Formatter } from 'js/toolbox';
import { Group, GroupType, Trend } from './group';
import * as components from "../../components";
import moment from 'moment';
import _ from 'lodash';

export class Project {
  id: string;
  name: string;
  cost: ProjectCost;

  static fromJSON(json: any): Project {
    const project = new Project();

    project.id = json.id as string;
    project.name = json.name as string;
    project.cost = ProjectCost.fromJSON(json.cost);

    return project;
  }

  get color(): string {
    return Formatter.colorFromName(this.name);
  }
}

export class DetailedProject extends Project {
  periodicCosts: ProjectCost[];
  static fromJSON(json: any): DetailedProject {
    const detailedProject = new DetailedProject();
    detailedProject.id = json.project.id as string;
    detailedProject.name = json.project.name as string;
    detailedProject.cost = ProjectCost.fromJSON(json.project.cost);

    const nonEmptyGroups = detailedProject.cost.groups.filter((group) => group.items.length != 0);
    detailedProject.cost.groups = nonEmptyGroups;

    const costs = json.costs.map(ProjectCost.fromJSON) as ProjectCost[];
    const missingCosts = detailedProject.missingCosts(costs);
    detailedProject.periodicCosts = _.chain(costs).concat(missingCosts).sortBy((c) => c.fromDate).value();
    return detailedProject;
  }

  get plotDomain(): [Date, Date] {
    const fromDate = moment(this.cost.fromDate);
    const toDate = moment(this.cost.toDate).subtract(1, `day`);
    return [fromDate.toDate(), toDate.toDate()];
  }

  findCostAt(date: Date) {
    return this.periodicCosts.find((cost) => moment(cost.fromDate).isSame(date, `day`));
  }

  static get Empty(): DetailedProject {
    const detailedProject = new DetailedProject();
    detailedProject.id = ``;
    detailedProject.name = `Empty project`;
    detailedProject.cost = ProjectCost.Empty;
    detailedProject.periodicCosts = [];
    return detailedProject;
  }

  missingCosts(costs: ProjectCost[]): ProjectCost[] {
    const fromDate = moment(this.cost.fromDate);
    const toDate = moment(this.cost.toDate);

    const missingCosts = [];

    let currentDate = fromDate.clone();
    while (currentDate.isBefore(toDate)) {
      const cost = costs.find((c) => moment(c.fromDate).isSame(currentDate, `day`));
      if (!cost) {
        const projectCost = ProjectCost.Empty;
        projectCost.fromDate= currentDate.toDate();
        projectCost.toDate = currentDate.add(1, `day`).toDate();
        missingCosts.push(projectCost);
      }
      currentDate = currentDate.add(1, `day`);
    }
    return missingCosts;
  }

  get plotData(): components.Charts.PlotData[] {
    return this.periodicCosts.map((cost) => {
      return {
        day: cost.fromDate,
        name: this.name,
        value: cost.rawTotal,
        details: {
          [this.name]: cost.rawTotal
        }
      };
    });
  }

  get plotDataBeforeToday(): components.Charts.PlotData[] {
    return this.periodicCostsBeforeToday.map((cost) => {
      return {
        day: cost.fromDate,
        name: this.name,
        value: cost.rawTotal,
        details: {
          [this.name]: cost.rawTotal
        }
      };
    });
  }

  get detailedPlotData(): components.Charts.PlotData[] {
    return this.periodicCosts.map((cost) => {
      const details = cost.groups.reduce<Record<string, number>>((acc, group) => {
        acc[group.type as string] = group.rawPrice;
        return acc;
      }, {});

      return {
        day: cost.fromDate,
        name: this.name,
        value: cost.rawTotal,
        details: details
      };
    });
  }

  get workflowPlotData(): components.Charts.PlotData[] {
    return this.periodicCostsBeforeToday.map((cost) => {
      const details = {
        'workflows': cost.workflowCount,
      };

      return {
        day: cost.fromDate,
        name: `workflows`,
        value: cost.workflowCount,
        details: details
      };
    });
  }

  plotDataForGroup(groupType: GroupType[]): components.Charts.PlotData[] {
    return this.periodicCosts.flatMap((cost) => {
      const groups = cost.groups.filter((g) => groupType.includes(g.type));
      return groups.map((group) => {
        let total = 0;
        const details = group.items.reduce<Record<string, number>>((acc, item) => {
          acc[item.type] = item.rawPrice;
          total += item.rawPrice;
          return acc;
        }, {});


        return {
          day: cost.fromDate,
          name: group.name,
          value: total,
          details: details
        };
      });
    });
  }

  get periodicCostsBeforeToday(): ProjectCost[] {
    const today = moment.utc().startOf(`day`);
    return this.periodicCosts.filter((cost) => moment(cost.fromDate).isBefore(today));
  }

  metricNames(): string[] {
    return _.chain(this.cost.groups)
      .flatMap((group) => group.items.map((item) => item.type))
      .uniq()
      .sort()
      .value();
  }

  metricNamesForGroup(groupType: GroupType): string[] {
    const group = this.cost.groups.find((g) => g.type === groupType);

    if (group) {
      return _.uniq(group.items.map((item) => item.type));
    } else {
      return [];
    }
  }
}

export class ProjectCost {
  fromDate: Date;
  toDate: Date;
  total: string;
  groups: Group[];
  workflowCount: number;
  trends: Trend[];

  static fromJSON(json: any): ProjectCost {
    const projectCost = new ProjectCost();

    const fromDate = moment.utc(json.from_date as string).startOf(`day`).format(`YYYY-MM-DD`);
    const toDate = moment.utc(json.to_date as string).startOf(`day`).format(`YYYY-MM-DD`);

    projectCost.fromDate = Formatter.parseDateToUTC(fromDate);
    projectCost.toDate = Formatter.parseDateToUTC(toDate);
    projectCost.total = json.total_price as string;
    projectCost.groups = json.spending_groups.map(Group.fromJSON) as Group[];

    const groupSortOrder = Object.values(GroupType);
    projectCost.groups = projectCost.groups.filter((group) => group).sort((a, b) => groupSortOrder.indexOf(a.type) - groupSortOrder.indexOf(b.type));

    projectCost.workflowCount = json.workflow_count as number;
    projectCost.trends = json.workflow_trends.map(Trend.fromJSON);

    return projectCost;
  }

  static get Empty(): ProjectCost {
    const projectCost = new ProjectCost();
    projectCost.fromDate = new Date();
    projectCost.toDate = new Date();
    projectCost.total = `$0.00`;
    projectCost.groups = [];
    projectCost.workflowCount = 0;
    projectCost.trends = [];
    return projectCost;
  }

  get rawTotal(): number {
    return Formatter.parseMoney(this.total);
  }

  get machineTimeGroup(): Group {
    return this.findGroup(GroupType.MachineTime);
  }

  get storageGroup(): Group {
    return this.findGroup(GroupType.Storage);
  }

  get priceTrend(): string {
    if(this.trends.length == 0) {
      return `new`;
    } else {
      const lastPrice = Formatter.parseMoney(this.trends[0].price);
      const currentPrice = Formatter.parseMoney(this.total);
      if(lastPrice > currentPrice) {
        return `down`;
      } else if(lastPrice < currentPrice) {
        return `up`;
      } else if (lastPrice == currentPrice){
        return `same`;
      }
    }
  }

  get usageTrend(): string {
    if(this.trends.length == 0) {
      return `new`;
    } else {
      const lastUsage = this.trends[0].usage;
      if(lastUsage > this.workflowCount) {
        return `down`;
      } else if(lastUsage < this.workflowCount) {
        return `up`;
      } else if (lastUsage == this.workflowCount){
        return `same`;
      }
    }
  }

  get groupTypes(): GroupType[] {
    return this.groups.map((g) => g.type);
  }

  private findGroup(type: GroupType): Group {
    const foundGroup = this.groups.find((g) => g.type === type);

    if (!foundGroup) {
      return Group.Empty;
    }

    return foundGroup;
  }
}
