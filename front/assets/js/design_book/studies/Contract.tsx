import { useEffect, useRef, useState } from "preact/hooks";

import { WorkspaceData } from "../../workspace/types";
import { dependencyTiers } from "../../workspace/layout/tiers";
import { drawWires, workspaceWires } from "../../workspace/graph/wires";
import { AttemptRail } from "../../workspace/components/AttemptRail";
import { BlockCard } from "../../workspace/components/BlockCard";
import { OutcomeNode } from "../../workspace/components/OutcomeNode";
import { PromotionCard } from "../../workspace/components/PromotionCard";

const WORKSPACE_DATA_URL = `/design-book/data/workspace/demo`;

export const Contract = () => {
  const [data, setData] = useState<WorkspaceData | null>(null);
  const [error, setError] = useState(``);
  const canvasRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const loadFixture = async () => {
      try {
        const response = await fetch(WORKSPACE_DATA_URL);

        if (!response.ok) {
          setError(`Fixture request failed with status ${response.status}`);

          return;
        }

        setData((await response.json()) as WorkspaceData);
      } catch {
        setError(`Fixture request failed`);
      }
    };

    void loadFixture();
  }, []);

  useEffect(() => {
    if (!data) {
      return;
    }

    const draw = () => {
      if (canvasRef.current) {
        drawWires(canvasRef.current, workspaceWires(data));
      }
    };

    const frame = requestAnimationFrame(draw);
    window.addEventListener(`resize`, draw);

    return () => {
      cancelAnimationFrame(frame);
      window.removeEventListener(`resize`, draw);
    };
  }, [data]);

  if (error) {
    return <div className="red f5">{error}</div>;
  }

  if (!data) {
    return <div className="gray f5">Loading fixture</div>;
  }

  const tiers = dependencyTiers(data.current.blocks);
  const currentAttempt = data.attempts.find(
    (attempt) => attempt.pipeline_id === data.current.pipeline_id
  );

  return (
    <div>
      <h2 className="f3 lh-title mb1">{data.workflow.name}</h2>
      <div className="f6 gray mb3">
        {data.workflow.branch} · {data.workflow.commit.sha.slice(0, 7)} ·{` `}
        {data.workflow.commit.author}
      </div>

      <AttemptRail attempts={data.attempts} currentPipelineId={data.current.pipeline_id}/>

      <div className="overflow-x-auto">
        <div className="relative pv3 pr3" ref={canvasRef} style={{ minWidth: `max-content` }}>
          <svg
            data-wires
            className="absolute top-0 left-0"
            style={{ pointerEvents: `none`, overflow: `visible` }}
          />
          <div className="relative flex items-center">
            {tiers.map((tier) => (
              <div
                key={tier.map((block) => block.name).join(`+`)}
                className="flex flex-column flex-shrink-0 mr4"
                style={{ rowGap: `1.25rem`, width: `15rem` }}
              >
                {tier.map((block) => (
                  <BlockCard key={block.name} block={block}/>
                ))}
              </div>
            ))}
            <div className="flex-shrink-0 mr4">
              <OutcomeNode
                result={currentAttempt ? currentAttempt.result : `unknown`}
                attemptIndex={currentAttempt ? currentAttempt.index : undefined}
                pipelineId={data.current.pipeline_id}
              />
            </div>
            <div className="flex flex-column flex-shrink-0" style={{ rowGap: `1rem` }}>
              {data.current.promotions.map((promotion) => (
                <PromotionCard key={promotion.name} promotion={promotion}/>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
