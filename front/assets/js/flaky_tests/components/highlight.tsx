import { useEffect, useRef } from "preact/hooks";

import Prism from 'prismjs';

import styled from "styled-components";

const QueryCode = styled.code`
  .token.keyword {
    color: #8658d6;
    font-weight: bold;
  }

  .token.value {
    color: #00a569;
  }

  .token.operator {
    color: #e53935;
  }

  .token.keyword-value-pair {
    display: inline-block;
    padding: 0px 5px;
    background: #f5f8f9;
    box-shadow: rgba(0, 0, 0, 0.2) 0px 0px 0px 1px, rgb(229, 232, 234) 0px -1px 1px 0px inset;
    border-radius: 3px;
    margin: 0px 3px;
  }

  white-space: pre-wrap;
  white-space: -moz-pre-wrap;
  white-space: -pre-wrap;
  white-space: -o-pre-wrap;
  word-wrap: break-word;
  font-family: 'Fakt Pro',-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Oxygen-Sans,Ubuntu,Cantarell,"Helvetica Neue",sans-serif;
  box-shadow: 0 0 0 1px rgba(0,0,0,.2), inset 0 -1px 1px 0 #e5e8ea;
  border-radius: 0px;
  background: #fff;
  display: block;
  padding: 5px 10px;
  overflow: hidden;
  overflow-x: auto;
  min-height: 100%;
  outline: none;
`;

export const allowedParams = [
  `@git.branch`,
  `@git.commit_sha`,
  `@test.name`,
  `@test.group`,
  `@test.file`,
  `@test.class.name`,
  `@test.suite`,
  `@test.runner`,
  `@metric.pass_rate`,
  `@metric.disruptions`,
  `@label`,
  `@is.resolved`,
  `@is.scheduled`,
  `@date.from`,
  `@date.to`,
];
const permittedKeywordPattern = new RegExp(allowedParams.map(x => x.replace(`.`, `\\.`)).join(`|`));

Prism.languages.query = {
  'keyword-value-pair': {
    pattern: new RegExp(`(${permittedKeywordPattern.source}):("[^"]*"?|[^:\\s]+)`),
    greedy: true,
    inside: {
      'keyword': {
        pattern: permittedKeywordPattern,
        greedy: false,
      },
      'value': {
        pattern: /:("[^"]*"?|[^:\s]+)/,
        greedy: true,
        inside: {
          'operator': /%|=|>|<=|!=|>|</,
        },
      },
    },
  },
  'keyword': {
    pattern: permittedKeywordPattern,
    greedy: false,
  },
};

interface HighlightProps {
  query: string;
  onQueryChange: (newQuery: string) => void;
  onSubmit: () => void;
  className?: string;
}

export const Highlight = (props: HighlightProps) => {
  const contentRef = useRef<HTMLDivElement>(null);
  const lastPropQueryRef = useRef(props.query);

  useEffect(() => {
    if (lastPropQueryRef.current !== props.query) {
      lastPropQueryRef.current = props.query;

      // Now, also update the content of contentEditable if it's not in focus
      // (to prevent disrupting user's interaction)
      const contentDiv = contentRef.current;
      if (contentDiv && document.activeElement !== contentDiv) {
        const highlighted = Prism.highlight(props.query, Prism.languages.query, `query`);
        contentDiv.innerHTML = highlighted;
      }
    }
  }, [props.query]);

  const saveCaretPosition = (context: HTMLElement): (() => void) => {
    const selection = window.getSelection();
    const range = selection?.getRangeAt(0);
    range?.setStart(context, 0);
    const len = range?.toString().length || 0;

    return function restore() {
      const pos = getTextNodeAtPosition(context, len);
      if (selection) {
        selection.removeAllRanges();
        const range = new Range();
        range.setStart(pos.node, pos.position);
        selection.addRange(range);
      }
    };
  };

  const getTextNodeAtPosition = (
    root: Node,
    index: number
  ): { node: Node, position: number } => {
    const NODE_TYPE = NodeFilter.SHOW_TEXT;
    const treeWalker = document.createTreeWalker(root, NODE_TYPE, function next(elem) {
      if (index > elem.textContent.length) {
        index -= elem.textContent.length;
        return NodeFilter.FILTER_REJECT;
      }
      return NodeFilter.FILTER_ACCEPT;
    });
    const c = treeWalker.nextNode();
    return {
      node: c ? c : root,
      position: index,
    };
  };


  const handleInput = () => {
    const contentDiv = contentRef.current;
    if (contentDiv) {
      const restore = saveCaretPosition(contentDiv);
      const content = contentDiv.textContent || ``;
      props.onQueryChange(content);

      if (content !== props.query) {
        const highlighted = Prism.highlight(content, Prism.languages.query, `query`);
        contentDiv.innerHTML = highlighted;
        restore();
      }
    }
  };

  // Forbid new lines
  const handleKeyPress = (e: KeyboardEvent) => {
    if(e.which == 13) {
      e.preventDefault();
      e.stopPropagation();
      props.onSubmit();
    }
  };

  return (
    <QueryCode
      contentEditable="true"
      onInput={handleInput}
      onKeyPress={handleKeyPress}
      onFocusOut={() => props.onSubmit() }
      ref={contentRef}
      className={`language-query ${props.className}`}
    >
    </QueryCode>
  );
};
