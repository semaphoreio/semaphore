import { h } from "preact";
import { useEffect, useRef, useState } from "preact/hooks";
import { select } from 'd3-selection';
import { curveBasis } from 'd3-shape';
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { graphlib, render } from 'dagre-d3';
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import * as yaml from 'js-yaml';

interface PipelinePreviewProps {
  yamlContent: string;
  previewVisible: boolean;
}

export const PipelinePreview = ({ yamlContent, previewVisible }: PipelinePreviewProps) => {
  const diagramRef = useRef<HTMLDivElement>(null);
  const [pipelineName, setPipelineName] = useState<string>(``);

  useEffect(() => {
    if (yamlContent && previewVisible && diagramRef.current) {
      try {
        const workflowData = yaml.load(yamlContent) as { name?: string, };
        setPipelineName(workflowData.name || `Pipeline`);
      } catch (error) {
        setPipelineName(`Pipeline`);
      }
      renderWorkflowDiagram();
    }
  }, [yamlContent, previewVisible]);

  const renderWorkflowDiagram = () => {
    try {
      const workflowData = yaml.load(yamlContent) as any;
      if (!workflowData || !workflowData.blocks) return;

      const g = new graphlib.Graph();
      g.setGraph({
        rankdir: `LR`,
        ranksep: 50,
        nodesep: 50,
        align: `UL`,
        ranker: `longest-path`,
        marginx: 10,
        marginy: 10
      });

      g.setDefaultEdgeLabel(() => ({}));

      // Clear existing SVG content
      const container = diagramRef.current;
      if (!container) return;
      const svg = select(container).select(`svg`);
      svg.selectAll(`*`).remove();
      // Remove all existing attributes
      const svgElement = svg.node() as SVGSVGElement;
      if (svgElement) {
        Array.from(svgElement.attributes).forEach(attr => {
          svgElement.removeAttribute(attr.name);
        });
      }
      svg.attr(`class`, `w-100`).style(`overflow`, `visible`);

      // Add nodes for each block
      workflowData.blocks.forEach((block: any) => {
        const jobsList = block.task?.jobs?.map((job: any) => 
          `<div class="normal pv1 bt b--lighter-gray">${String(job.name || job.commands?.[0] || `Job`)}</div>`
        ).join(``) || ``;

        g.setNode(block.name, {
          labelType: `html`,
          label: `<div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;">
    <a href="#" style="margin: 10px; min-width: 100px;" class="link dib v-top dark-gray bg-white shadow-1 pa2 br2" data-type="block" data-uid="${String(block.name)}">
      <h4 class="f4 normal gray mb2">${String(block.name)}</h4>
      ${String(jobsList)}
    </a>
  </div>`,
          padding: -10
        });
      });

      // Add edges for dependencies
      workflowData.blocks.forEach((block: any, index: number) => {
        if (block.dependencies && block.dependencies.length > 0) {
          // Handle explicit dependencies
          block.dependencies.forEach((dep: string) => {
            g.setEdge(dep, block.name, {
              arrowhead: `undirected`,
              style: `stroke: gray; fill: transparent;`,
              curve: curveBasis
            });
          });
        } else if (index > 0) {
          // Infer dependency from previous block when no explicit dependencies are defined
          const previousBlock = workflowData.blocks[index - 1];
          g.setEdge(previousBlock.name, block.name, {
            arrowhead: `undirected`,
            style: `stroke: gray; fill: transparent;`,
            curve: curveBasis
          });
        }
      });

      // Create and run the renderer
      const r = new render();
      r(svg, g);

      // Adjust SVG size and viewBox
      const outputNode = svg.select(`g`).node() as SVGGElement;
      if (outputNode) {
        const bbox = outputNode.getBoundingClientRect();
        const width = Math.max(bbox.width, g.graph().width as number);
        const height = Math.max(bbox.height, g.graph().height as number);
        svg
          .attr(`width`, width)
          .attr(`height`, height)
          .attr(`viewBox`, `0 0 ${width} ${height}`)
          .style(`max-width`, `100%`)
          .style(`min-width`, `800px`);
      }

      // Style fixes
      svg.selectAll(`.label-container`)
        .attr(`rx`, `0`)
        .attr(`ry`, `0`)
        .style(`fill`, `transparent`)
        .style(`stroke`, `transparent`);

      svg.selectAll(`.edgePath path`)
        .style(`stroke-width`, `2px`);

    } catch (error: unknown) {
      Notice.error(`Error rendering workflow diagram: ${error instanceof Error ? error.message : String(error)}`);
    }
  };

  return (
    <div className="dib v-top bg-washed-gray pa3 br3 ba b--black-075 mt-auto mb-auto" style={{ overflow: `auto`, maxWidth: `100%` }} ref={diagramRef}>
      <div className="mb2 pb1 nt1">
        <h3 className="f4 normal gray mb0 pr3">{pipelineName}</h3>
      </div>
      <svg className="w-100" style={{ overflow: `visible` }}></svg>
    </div>
  );
};
