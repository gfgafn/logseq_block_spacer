// @ts-check

const path = require('path');

const isProduction = process.env.NODE_ENV === 'production';

/** @type {import('@rspack/cli').Configuration} */
const config = {
    entry: {
        main: './src/Index.bs.js',
    },
    builtins: {
        html: [
            {
                template: 'index.html',
            },
        ],
    },
    mode: isProduction ? 'production' : 'development',
    output: {
        filename: '[name]-[contenthash].js',
        path: path.resolve(__dirname, 'dist'),
        clean: true,
    },
    devtool: isProduction ? false : 'inline-source-map',
    stats: isProduction ? 'verbose' : 'errors-warnings',
};

module.exports = config;
