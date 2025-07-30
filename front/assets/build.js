const esbuild = require('esbuild')
const fs = require('fs-extra')
const path = require('path')
const { exec } = require('child_process')
const { promisify } = require('util')

const execAsync = promisify(exec)
const bundle = true
const logLevel = process.env.ESBUILD_LOG_LEVEL || 'silent'
const watch = !!process.env.ESBUILD_WATCH
const isProd = process.env.MIX_ENV === 'prod' || process.env.NODE_ENV === 'production'

const plugins = [
  // Add and configure plugins here
]

const outputDir = '../priv/static/assets'

// Function to process CSS files
const processCss = async () => {
  console.log('Processing CSS files...')

  try {
    // Process main.css which imports all other CSS files
    const inputFile = 'css/main.css'
    const outputFile = path.join(outputDir, 'css/app.css')

    // Set NODE_ENV for PostCSS to handle minification
    const env = isProd ? 'NODE_ENV=production' : 'NODE_ENV=development'
    const postcssCmd = `${env} npx postcss ${inputFile} -o ${outputFile}`

    await execAsync(postcssCmd)
    console.log(`CSS processed successfully (${isProd ? 'production' : 'development'} mode)`)

  } catch (error) {
    console.error('Error processing CSS:', error)
    throw error
  }
}

// Function to copy static assets
const copyAssets = async () => {
  console.log('Copying static assets to output directory...')

  fs.ensureDirSync(path.join(outputDir, 'css'))
  fs.ensureDirSync(path.join(outputDir, 'fonts'))
  fs.ensureDirSync(path.join(outputDir, 'images'))

  // Process CSS files
  await processCss()

  // Copy fonts and images
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
  esbuild.context(buildOptions).then(async context => {
    context.watch()
    await copyAssets()

    const chokidar = require('chokidar')
    const cssDir = path.join(__dirname, 'css')

    const cssWatcher = chokidar.watch(cssDir, {
      persistent: true,
      ignoreInitial: true,
      usePolling: true, // REQUIRED for macOS Docker
      interval: 1000,
      binaryInterval: 1000,
      awaitWriteFinish: {
        stabilityThreshold: 500,
        pollInterval: 100
      },
      useFsEvents: false,
      alwaysStat: true,
      depth: 99,
      atomic: false
    })

    cssWatcher
      .on('change', async (path) => {
        // Only process CSS files
        if (path.endsWith('.css')) {
          console.log('CSS file changed, reprocessing...')
          try {
            await processCss()
          } catch (error) {
            console.error('Error processing CSS:', error)
          }
        }
      })
      .on('ready', () => console.log('CSS watcher ready'))

    process.stdin.on('close', () => {
      cssWatcher.close()
      context.dispose()
      process.exit(0)
    })
    process.stdin.resume()
  })
} else {
  esbuild.build(buildOptions).then(async () => {
    await copyAssets()
  }).catch(error => {
    console.error('Build error:', error)
    process.exit(1)
  })
}
