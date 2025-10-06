
import moment from "moment";

export const Duration = ({ duration, className }: { duration: number, className?: string }) => {
  duration = (Math.floor(duration / 1000000) * 1000000) / 1000000;
  const dur = moment.duration(duration);
  const milliseconds = dur.milliseconds();

  let format = ``;

  if (duration >= 3600000) {
    format += `${`${dur.hours()}`.padStart(2, `0`)}:`;
    format += `${`${dur.minutes()}`.padStart(2, `0`)}h`;
  } else {
    format += `${`${dur.minutes()}`.padStart(2, `0`)}:`;
    format += `${`${dur.seconds()}`.padStart(2, `0`)}.`;
  }

  return (
    <span className={className}>
      {format}
      {duration < 3600000 && <span className="o-60">{`${milliseconds}`.padStart(3, `0`)}</span>}
    </span>
  );
};
