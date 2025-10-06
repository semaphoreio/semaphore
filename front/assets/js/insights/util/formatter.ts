import moment from "moment";

const isZeroDate = (date: Date): boolean => {
  return moment(date).unix() == 0;
};

export const Formatter = {
  dateDiff: (durationStart: Date, durationEnd: Date): string => {
    if(isZeroDate(durationStart) || isZeroDate(durationEnd)) {
      return `N/A`;
    }

    const dateDiff = moment(durationStart).diff(moment(durationEnd));
    const duration = moment.duration(dateDiff);

    return duration.humanize(true);
  },

  dateDiffAge: (durationStart: Date, durationEnd: Date): string => {
    if(isZeroDate(durationStart) || isZeroDate(durationEnd)) {
      return `N/A`;
    }

    const dateDiff = moment(durationStart).diff(moment(durationEnd));
    const duration = moment.duration(dateDiff);

    return duration.humanize(false) + ` old`;
  },

  duration: (secs: number): string => {
    if(secs === 0) {
      return `N/A`;
    }

    // Use arithmetic-based formatting (days/hours/minutes/seconds) to avoid
    // timezone-dependent behavior of `moment.unix(...).format(...)`.
    const secondsInDay = 24 * 3600;
    const secondsInHour = 3600;
    const secondsInMinute = 60;

    let remaining = Math.floor(secs);
    const days = Math.floor(remaining / secondsInDay);
    remaining = remaining % secondsInDay;
    const hours = Math.floor(remaining / secondsInHour);
    remaining = remaining % secondsInHour;
    const minutes = Math.floor(remaining / secondsInMinute);
    const seconds = remaining % secondsInMinute;

    if (days > 0) {
      return `${days}d ${hours}h ${minutes}m ${seconds}s`;
    }

    if (hours > 0) {
      return `${hours}h ${minutes}m ${seconds}s`;
    }

    if (minutes > 0) {
      return `${minutes}m ${seconds}s`;
    }

    return `${seconds}s`;
  },

  percentage: (percentage: number): string => {
    return `${percentage}%`;
  },

  dailyRate: (total: number, days: number): string => {
    if(days == 0 || total == 0) {
      return `N/A`;
    }

    const dailyRate = total / days;

    if (dailyRate <= 1/30) {
      return `< 1/month`;
    }

    if (dailyRate >= 1/30 && dailyRate < 1/7) {
      return `${Math.round(dailyRate * 30)}/month`;
    }

    if (dailyRate >= 1/7 && dailyRate < 5/7) {
      return `${Math.round(dailyRate * 7)}/week`;
    }

    return `${Math.round(dailyRate)}/day`;
  },

  date: (date: Date): string => {
    return moment(date).utc().format(`DD MMM YYYY`);
  },

  dateTime: (date: Date): string => {
    return moment(date).utc().format(`DD MMM YYYY HH:mm:ss`);
  }
};
