
// We want to have a nice distribution on the Y axis. "Nice" in this
// context means:
//
// - that we will have 6 equly distrubuted lines
// - Min value is not < 0
// - All numbers displayed are whole numbers (i.e 193 is not acceptable)
// - We only want to see "whole" numbers, 0, 10, 20, 100, 200, 300, 1000, 2000
//
export const CalculateOptimalRange = (values: number[]): number[] => {
  const zeroState = [0, 1, 2, 3, 4, 5];

  if(values.length == 0) {
    return zeroState;
  }

  let max = Math.max(...values);
  let min = 0;

  if ((min == max && min == 0) || max < 5) {
    return zeroState;
  }

  while(!isItNice(min, max)) {
    if(min == 0) {
      max = max + 1;
    } else {
      min = min - 1;
    }
  }

  const axisValues = [
    min,
    min + ((max-min)/5) * 1,
    min + ((max-min)/5) * 2,
    min + ((max-min)/5) * 3,
    min + ((max-min)/5) * 4,
    max
  ].map(d => Math.floor(d));

  return axisValues;
};

function isItNice(min: number, max: number) {
  const range = max - min;

  const dividesNicely = (range % 5 == 0);
  const upperValueIsRound = isOneNumberAllZeros(max);
  const bottomValueIsRound = isOneNumberAllZeros(min);

  return dividesNicely && upperValueIsRound && bottomValueIsRound;
}

//
// Example:
//
// 0  -> true
// 8  -> true
// 18 -> false
// 20 -> true
// 81 -> false
// 100 -> true
// 112 -> false
// 110 -> false
// 200 -> true
//
function isOneNumberAllZeros(value: number) {
  const digits = value.toString().length;
  const divisor = Math.pow(10, digits-1);

  return value % divisor == 0;
}
