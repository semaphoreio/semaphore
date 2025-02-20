import { h } from "preact";
import $ from "jquery";
const assetPath = $(`meta[name='assets-path']`).attr(`content`);

interface AssetProps extends preact.JSX.ImgHTMLAttributes {
  path: string;
}

export default function ({
  path: path,
  ...props
}: AssetProps) {
  const url = new URL(`./${path}`, `${assetPath}/`).href;
  return <img src={url} {...props}/>;
}
