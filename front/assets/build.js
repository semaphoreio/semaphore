const esbuild = require('esbuild')

const bundle = true
const logLevel = process.env.ESBUILD_LOG_LEVEL || 'silent'
const watch = !!process.env.ESBUILD_WATCH

const plugins = [
  // Add and configure plugins here
]

const buildOptions = {
  minify: true,
  sourcemap: (process.env.MIX_ENV || 'prod') != 'prod',
  entryPoints: ['js/app.js'],
  external: ['fs'],
  bundle,
  target: 'es2020',
  plugins,
  outdir: '../priv/static/assets',
  logLevel,
  loader: {
    '.tsx': 'tsx',
    '.ts': 'ts',
    '.js': 'jsx',
    '.ttf': 'file'
  },
  jsxImportSource: 'preact',
  jsx: 'automatic',
  jsxFragment: "Fragment",
  alias: {
    'react': 'preact/compat',
    'react-dom': 'preact/compat'
  }
}

if (watch) {
  esbuild.context(buildOptions).then(context => {
    context.watch()
    process.stdin.on('close', () => {
      context.dispose()
      process.exit(0)
    })
    process.stdin.resume()
  })
} else {
  esbuild.build(buildOptions)
}
