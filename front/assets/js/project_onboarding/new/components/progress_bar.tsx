import { Fragment } from "preact/jsx-runtime";
import { useSteps } from "../stores/create/steps";


export const ProgressBar = () => {
  const { state } = useSteps<{ id: string, title: string, }>();

  const steps = state?.steps || [];

  return (
    <div className="dn db-m mb4">
      {steps.map((step, index) => (
        <Fragment key="{step.id}">
          {(step.id !== state.currentStepId) && <span>{index + 1}. {step.title}</span>}
          {(step.id === state.currentStepId) && <span className="ph3 bg-green white br-pill">{index + 1}. {step.title}</span>}
          {index < state.steps.length - 1 && (
            <span className="gray mh2">→</span>
          )}
        </Fragment>
      ))}
    </div>
  );
};
