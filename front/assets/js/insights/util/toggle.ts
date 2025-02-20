import { useCallback, useState } from 'preact/hooks';


export const useToggle = () => {
  const [show, setValue] = useState(false);
  const toggle = useCallback(() => {
    setValue(!show);
  }, [show]);
  return { show, toggle };
};