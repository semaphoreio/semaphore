import { h, FunctionComponent } from "preact";

export type OnboardingStep = 
  | `select-type`
  | `setup-project`
  | `select-environment`
  | `setup-workflow`;

interface ProgressBarProps {
  currentStep: OnboardingStep;
}

// eslint-disable-next-line react/prop-types
export const ProgressBar: FunctionComponent<ProgressBarProps> = ({ currentStep }) => {
  const steps = [
    { id: `select-type`, label: `1. Select project type` },
    { id: `setup-project`, label: `2. Setup the project` },
    { id: `select-environment`, label: `3. Select the environment` },
    { id: `setup-workflow`, label: `4. Setup workflow` },
  ];

  return (
    <div className="dn db-m mb4">
      {steps.map((step, index) => (
        <>
          <span
            className={`${
              currentStep === step.id ? `ph3 pv1 bg-green white br-pill` : ``
            }`}
          >
            {step.label}
          </span>
          {index < steps.length - 1 && (
            <span className="gray mh2">→</span>
          )}
        </>
      ))}
    </div>
  );
};
