export var Paths = {

  relative(from, to) {
    function trim(arr) {
      let start = 0;
      for (; start < arr.length; start++) {
        if (arr[start] !== '') break;
      }

      let end = arr.length - 1;
      for (; end >= 0; end--) {
        if (arr[end] !== '') break;
      }

      if (start > end) return [];
      return arr.slice(start, end - start + 1);
    }

    let fromParts = trim(from.split('/'));
    let toParts = trim(to.split('/'));

    let length = Math.min(fromParts.length, toParts.length);
    let samePartsLength = length;
    for (let i = 0; i < length; i++) {
      if (fromParts[i] !== toParts[i]) {
        samePartsLength = i;
        break;
      }
    }

    let outputParts = [];
    for (let i = samePartsLength; i < fromParts.length - 1; i++) {
      outputParts.push('..');
    }

    outputParts = outputParts.concat(toParts.slice(samePartsLength));

    return outputParts.join('/');
  }

}
