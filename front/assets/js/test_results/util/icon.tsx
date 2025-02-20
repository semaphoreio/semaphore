import { h } from "preact";
import $ from "jquery";
const assetPath = $(`meta[name='assets-path']`).attr(`content`);

export default function (props: { path: string, class?: string, width?: string, height?: string, alt?: string, }) {
  const url = new URL(`./${props.path}`, `${assetPath}/`).href;

  const width = props.width || `16`;
  const height = props.height || `16`;
  const alt = props.alt;

  return (
    <img src={url} width={`${width}`} height={`${height}`} className={props.class} alt={alt}/>
  );
}
