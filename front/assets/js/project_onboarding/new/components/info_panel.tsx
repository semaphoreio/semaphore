
import * as toolbox from "js/toolbox";

interface InfoPanelProps {
  title?: string;
  subtitle?: string;
  svgPath: string;
  svgAlt?: string;
  additionalInfo?: string;
}

export const InfoPanel = ({
  title = `Select project type`,
  svgPath,
  svgAlt = `illustration`,
  subtitle = `Get started by linking your code repository`,
  additionalInfo = `Each project maps directly to a single repository.\nChoose your repository provider to get started.`,
}: InfoPanelProps) => {
  return (
    <div className="w-third ph4-l">
      <h1 className="f2 f1-m mb0">{title}</h1>
      <p className="mb4 measure">{subtitle}</p>
      <div>
        <toolbox.Asset
          path={svgPath}
          width="170"
          className="db ml2"
          alt={svgAlt}
        />
      </div>
      <p className="f6 black-60 measure mv3">
        {additionalInfo.split(`\n`).map((text, i) => (
          <>
            {text}
            {i < additionalInfo.split(`\n`).length - 1 && <br/>}
          </>
        ))}
      </p>
    </div>
  );
};
