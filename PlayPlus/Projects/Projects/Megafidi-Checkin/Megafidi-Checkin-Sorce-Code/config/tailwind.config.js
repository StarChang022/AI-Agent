const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}',
		"./node_modules/flowbite/**/*.js",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
			colors: {
				"gray-theme": {
					"lightest": "#F2F2F3",
					"lighter": "#E4E4E4",
					"light": "#A8AAAE",
					"DEFAULT": "#4B4B4B",
				},
				"orange-theme": {
					"lightest": "#FFFAF5",
					"lighter": "#FFF1E3",
					"light": "#FFAF64",
					"DEFAULT": "#FF9E43",
				},
				"green-theme": {
					"light": "#DFF7E9",
					"DEFAULT": "#29C770",
				},
				"red-theme": {
					"light": "#F9696B",
					"DEFAULT": "#EA5355",
				},
				"purple-theme": {
					"light": "#9085FC",
					"DEFAULT": "#7367F0",
				}
			}
    },
  },
  corePlugins: {
    aspectRatio: false,
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/line-clamp'),
    require('@tailwindcss/typography'),
		require('flowbite/plugin')
  ]
}
