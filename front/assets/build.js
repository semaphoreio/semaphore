const esbuild = require('esbuild')
const fs = require('fs-extra')
const path = require('path')

const bundle = true
const logLevel = process.env.ESBUILD_LOG_LEVEL || 'silent'
const watch = !!process.env.ESBUILD_WATCH

const plugins = [
  // Add and configure plugins here
]

const outputDir = '../priv/static/assets'

// Function to copy static assets
const copyAssets = () => {
  console.log('Copying original assets to output directory...')

  fs.ensureDirSync(path.join(outputDir, 'css'))
  fs.ensureDirSync(path.join(outputDir, 'fonts'))
  fs.ensureDirSync(path.join(outputDir, 'images'))

  fs.copySync('css', path.join(outputDir, 'css'), { overwrite: true })
  fs.copySync('fonts', path.join(outputDir, 'fonts'), { overwrite: true })
  fs.copySync('images', path.join(outputDir, 'images'), { overwrite: true })

  console.log('Assets copied successfully')
}

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
    copyAssets()
    process.stdin.on('close', () => {
      context.dispose()
      process.exit(0)
    })
    process.stdin.resume()
  })
} else {
  esbuild.build(buildOptions).then(() => {
    copyAssets()
  }).catch(error => {
    console.error('Build error:', error)
    process.exit(1)
  })
}
