export const formatDuration = (milliseconds: number): string => {
  const totalSeconds = Math.round(milliseconds / 1000);

  if (totalSeconds < 60) {
    return `${totalSeconds}s`;
  }

  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;

  return `${minutes}:${seconds.toString().padStart(2, `0`)}`;
};

export const resultTextColor = (result: string): string => {
  switch (result) {
    case `passed`:
      return `green`;
    case `failed`:
      return `red`;
    default:
      return `gray`;
  }
};

export const shortId = (id: string): string => id.slice(0, 8);
