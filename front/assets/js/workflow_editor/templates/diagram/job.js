export class Job {
  static render(job, hideBorderOnFirstJob) {
    let jobClass = "normal pv1 bt b--lighter-gray"
    let firstJobClass = hideBorderOnFirstJob ? "normal pv1" : jobClass

    if(job.hasParallelismEnabled()) {
      let output = ""

      for(let i = 0; i < job.parallelism; i++) {
        let name = `${job.name} - ${i+1}/${job.parallelism}`

        output += `<div class="${i === 0 ? firstJobClass : jobClass }">${escapeHtml(name)}</div>`
      }

      return output
    }

    if(job.hasMatrixEnabled()) {
      let output = ""

      matrixJobNames(job.matrix).forEach((name, i) => {
        output += `<div class="${i === 0 ? firstJobClass : jobClass}">${escapeHtml(job.name)} - ${escapeHtml(name)}</div>`
      })

      return output
    }


    return `<div class="${firstJobClass}">${escapeHtml(job.name)}</div>`
  }
}

function cartesianProduct(arr) {
  return arr.reduce((a, b) =>
                    a.map(x => b.map(y => x.concat(y)))
                    .reduce((a, b) => a.concat(b), []), [[]]);
}

function matrixJobNames(matrix) {
  let names = matrix.map((e) => {
    return e.values.map((v) => {
      return `${e.env_var}=${v}`
    })
  })

  return cartesianProduct(names).map(p => p.join(", "))
}
