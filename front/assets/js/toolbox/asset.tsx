import $ from "jquery";
const assetPath = $(`meta[name='assets-path']`).attr(`content`);

interface AssetProps extends preact.JSX.ImgHTMLAttributes {
  path: string;
}

export default function ({
  path: path,
  ...props
}: AssetProps) {
  const url = new URL(`${assetPath}/${path}`, `${location.origin}/`).href;
  return <img src={url} {...props}/>;
}
