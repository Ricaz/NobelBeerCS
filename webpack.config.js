var path = require('path');

module.exports = {
	mode: 'development',
	watch: true,
	entry: './src/webapp/app.js',
	module: {
		rules: [
			{
				test: /\.js$/,
				exclude: /node_modules/,
				use: { 
					loader: 'babel-loader',
					options: {
						presets: ['@babel/preset-env']
					}
				}
			}

		]
	},
	resolve: {
		alias: {
			vue: 'vue/dist/vue.js'
		}
	},
	output: {
		path: path.resolve(__dirname, 'dist/assets/js'),
		filename: 'bundle.js'
	}
};
