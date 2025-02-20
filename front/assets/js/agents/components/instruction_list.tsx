import styled from "styled-components";

export const InstructionList = styled.div`
  padding-left: 50px;
  position: relative;
  counter-reset: b;

  > ol {
    list-style-type: none;
    margin: 0;
    padding: 0;

    > li {
      position: relative;
      margin-bottom: 20px;
      padding-bottom: 10px;
    }

    > li::before {
      align-items: center;
      background-color: #00359f;
      border-radius: 50%;
      color: #fff;
      content: counter(b);
      counter-increment: b;
      display: flex;
      height: 30px;
      justify-content: center;
      position: absolute;
      width: 30px;
      left: -45px;
      top: -4px;
      z-index: 1;
    }

    > li::after {
      background-color: #b5bcc0;
      content: "";
      left: -30px;
      position: absolute;
      top: 15px;
      bottom: -16px;
      width: 1px;
    }

    > li:last-child::after {
      display: none;
    }
  }

  ul {
    margin-top: 10px;
    li {
      margin-bottom: 5px;
    }
  }
`;
