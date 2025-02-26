const esbuild = require('esbuild')
const fs = require('fs')
const path = require('path')

const bundle = true
const logLevel = process.env.ESBUILD_LOG_LEVEL || 'silent'
const watch = !!process.env.ESBUILD_WATCH

const plugins = [
  // Add and configure plugins here
]

const outputDir = '../priv/static/assets'

const copyDir = (src, dest) => {
  const files = fs.readdirSync(src)
  
  for (const file of files) {
    const srcPath = path.join(src, file)
    const destPath = path.join(dest, file)
    fs.copyFileSync(srcPath, destPath)
  }
}

// Function to copy static assets
const copyAssets = () => {
  console.log('Copying original assets to output directory...')
  
  copyDir('css', path.join(outputDir, 'css'), { overwrite: true })
  copyDir('fonts', path.join(outputDir, 'fonts'), { overwrite: true })
  copyDir('images', path.join(outputDir, 'images'), { overwrite: true })
  
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