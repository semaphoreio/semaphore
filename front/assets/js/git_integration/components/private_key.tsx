import { Fragment } from "preact";
import { useRef } from "preact/hooks";

interface PrivateKeyBoxProps {
  value: string;
  editUrl: string;
}

export const PrivateKeyBox = ({ value, editUrl }: PrivateKeyBoxProps) => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const formRef = useRef<HTMLFormElement>(null);

  const csrfToken = document
    .querySelector(`meta[name="csrf-token"]`)
    .getAttribute(`content`);

  const handleFileChange = () => {
    if (fileInputRef.current && formRef.current) {
      const selectedFile = fileInputRef.current.files?.[0];

      if (selectedFile && selectedFile.type === `application/x-x509-ca-cert`) {
        // add csrf token to the form
        const csrfInput = document.createElement(`input`);
        csrfInput.type = `hidden`;
        csrfInput.name = `_csrf_token`;
        csrfInput.value = csrfToken;

        formRef.current.appendChild(csrfInput);


        const fileInput = document.createElement(`textarea`);
        fileInput.name = `pem`;
        fileInput.style.display = `none`;

        const reader = new FileReader();
        reader.onload = (e) => {
          fileInput.value = e.target?.result as string;

          formRef.current.submit();
        };
        reader.readAsText(selectedFile);

        formRef.current.appendChild(fileInput);
      } else {
        alert(`Please upload a valid PEM file.`);
      }
    }
  };

  return (
    <Fragment>
      <div className="mv3 br3 shadow-3 bg-white pa3 bb b--black-075">
        <div className="flex items-center justify-between mb2 pb3  bb bw1 b--black-075 br3 br--top">
          <div className="flex items-center">
            <span className="material-symbols-outlined mr2">key</span>
            <span className="b f5">Private key</span>
          </div>
        </div>
        <pre className="f6 bg-washed-yellow mb3 ph3 pv2 ba b--black-075 br3">
          {value}
        </pre>
        <div className="flex items-center justify-between">
          <div className="flex items-center">
            <span className="material-symbols-outlined mr1 f4">warning</span>
            <div className="f6 gray">
              Verify Key SHA256 matches GitHub App&apos;s key
            </div>
          </div>
          {/* PEM FILE UPLOAD DIV */}
          <div>
            <form
              method="POST"
              ref={formRef}
              encType="multipart/form-data"
              action={editUrl}
            >
              <input
                type="file"
                className="btn btn-primary btn-small"
                ref={fileInputRef}
                accept=".pem"
                style={{ display: `none` }} // Hide the default file input
                onChange={handleFileChange}
              />
              <button
                type="button"
                className="btn btn-primary btn-small"
                onClick={() => {
                  if (fileInputRef.current) {
                    fileInputRef.current.click();
                  }
                }}
              >
                Upload
              </button>
            </form>
          </div>
        </div>
      </div>
    </Fragment>
  );
};
