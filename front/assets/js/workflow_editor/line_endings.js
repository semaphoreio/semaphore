//
// Module for determining and enforing line-endings in strings.
//
// Primary use of this module is to preserve the user choice of line-endings
// in Pipeline YAML files while in the editor.
//
var CRLF = "\r\n"
var LF   = "\n"

export var LineEndings = {

  //
  // Returns the dominent line-ending in a string.
  //
  // If the number LF >= CRLF => dominant one is LF
  // If the number CRLF > LF  => dominant one is CRLF
  // If the number CRLF = LF  => the algorithm has a bias of LF
  //
  dominantLineEnding: (string) => {
    let CRLFCount = 0
    let LFCount = 0

    for (var i = 1; i < string.length; i++) {
      let c = string.charAt(i)

      if(c === "\n") {
        if(string.charAt(i - 1) === "\r") {
          CRLFCount++
        } else {
          LFCount++
        }
      }
    }

    //
    // If LF and CRLF are equal, our bias is toward unix like
    // systems and we choose LF
    //
    if(LFCount >= CRLFCount) {
      return LF
    } else {
      return CRLF
    }
  },

  //
  // Enforces line endings in a string.
  //
  // Examples:
  //
  //   enforceLineEnding("a\r\nb", "\n") # => "a\nb"
  //
  enforceLineEnding: (string, ending) => {
    if(ending === LF) {
      return string.replace(/\r/g, "")
    }

    if(ending === CRLF) {
      return string.split(/\r\n/g).map(l => l.replace(/\n/g, CRLF)).join(CRLF)
    }
  }
}
