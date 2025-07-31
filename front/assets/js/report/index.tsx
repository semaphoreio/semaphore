import { render } from "preact";

import MarkdownIt, { PluginSimple } from "markdown-it";
import markdownItTextualUml from "markdown-it-textual-uml";
import Mermaid from "mermaid";

import * as toolbox from "js/toolbox";
import { useEffect, useState } from "preact/hooks";

Mermaid.initialize({ startOnLoad: false, theme: `default`, securityLevel: `strict` });
const md = MarkdownIt().use(markdownItTextualUml as PluginSimple);

export default function ({ config, dom }: { dom: HTMLElement, config: any, }) {
  render(<App reportUrl={config.reportUrl} context={config.reportContext}/>, dom);
}

enum ReportContext {
  Job = `job`,
  Workflow = `workflow`,
  Project = `project`,
}

const App = (props: { reportUrl: string, context: ReportContext, }) => {
  const [markdown, setMarkdown] = useState(``);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(``);
  const [reportExists, setReportExists] = useState(true);


  const fetchReport = async () => {
    try {
      setLoading(true);
      setError(``);
      const response = await fetch(props.reportUrl);
      setLoading(false);

      if(response.status == 404) {
        setReportExists(false);

        return;
      }

      if (!response.ok) {
        setError(`Failed to fetch report: ${response.statusText}`);
        return;
      }

      const text = await response.text();

      setReportExists(text.length > 0);
      setMarkdown(text);
    } catch (e) {
      setError(`Fetching report failed.`);
      setLoading(false);
    }
  };

  useEffect(() => {
    void fetchReport();
  }, []);

  return (
    <Loader loading={loading} error={error}>
      {reportExists && <MarkdownBody markdown={markdown}/>}
      {!reportExists && <ReportInstructions context={props.context}/>}
    </Loader>
  );
};

const MarkdownBody = (props: { markdown: string, }) => {
  useEffect(() => {
    if (props.markdown) {
      setTimeout(() => {
        void Mermaid.run();
      }, 100);
    }
  }, [props.markdown]);

  return (
    <div
      className="markdown-body"
      dangerouslySetInnerHTML={{ __html: md.render(props.markdown) }}
    />
  );
};

const ReportInstructions = (props: { context: ReportContext, }) => {
  let command = ``;

  switch (props.context) {
    case ReportContext.Job:
      command = `artifact push job -f -d .semaphore/REPORT.md REPORT.md`;
      break;
    case ReportContext.Workflow:
      command = `artifact push workflow -f -d .semaphore/REPORT.md REPORT.md`;
      break;
    case ReportContext.Project:
      command = `artifact push project -f -d .semaphore/REPORT.md REPORT.md`;
      break;
  }

  return (
    <div className="bg-washed-yellow br3 pa3 pa4-m ba b--black-075 w-100">
      <div className="pv3-m mw7 center">
        <h2 className="f3 mb0">Your Markdown reports will appear here.</h2>
        <p className="f4 normal mb4">
           These reports help share key details about your {props.context}, like build metrics or custom insights.
        </p>
        <div className="flex-m">
          <div className="flex-shrink-0 dn db-m nl4 ph4">
            <toolbox.Asset path="images/attached-file.svg" width="246" height="200"/>
          </div>
          <div className="flex-auto pl2-m">
            <div>
              <div className="flex mb2">
                <div className="bg-dark-gray white b w2 h2 flex-shrink-0 flex items-center justify-center br-100">
                  1
                </div>
                <div className="flex-auto pl3 nt1">
                  <h3 className="f4 mb0">Create your Markdown report</h3>
                  <p className="measure-wide">
                    Create a Markdown file with the contents you&apos;d like to display here.
                  </p>
                </div>
              </div>
              <div className="flex mb2">
                <div className="bg-dark-gray white b w2 h2 flex-shrink-0 flex items-center justify-center br-100">
                  2
                </div>
                <div className="pl3 nt1">
                  <h3 className="f4 mb0">Push your Markdown file as an artifact</h3>
                  <p className="measure-wide">
                    Upload your Markdown file by running the command below:
                  </p>
                  <pre className="bg-white ba b--black-10 br2 pa2 f6 mt2">
                    {command}
                  </pre>
                </div>
              </div>
              <div className="flex mb2">
                <div className="bg-dark-gray white b w2 h2 flex-shrink-0 flex items-center justify-center br-100">
                  3
                </div>
                <div className="flex-auto pl3 nt1">
                  <h3 className="f4 mb0">Your report will show up here</h3>
                  <p className="measure-wide">
                    Once your job has finished and pushed the report, it will show up here. That&apos;s it — no extra steps needed!
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

interface LoaderProps {
  loading: boolean;
  error: string;
  children: React.ReactNode;
}

const Loader = ({
  loading,
  error,
  children,
}: LoaderProps) => {
  if (loading) {
    return (
      <div className="flex items-center justify-center">
        <span className="f6 gray">Loading report</span>
        <toolbox.Asset path="images/spinner-2.svg" width="25" height="25"/>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center">
        <span className="f6 red">Loading report failed</span>
      </div>
    );
  }

  return <div className="mt2">{children}</div>;
};
