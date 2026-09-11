/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/views/**/*.php',
    './public/**/*.php'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['DM Sans', 'sans-serif'],
        display: ['Space Grotesk', 'sans-serif']
      },
      colors: {
        ink: '#101513',
        paper: '#f6f5f1',
        signal: '#b8e64b',
        alert: '#ef6b4a',
        moss: '#688d1b'
      },
      boxShadow: {
        card: '0 1px 2px rgba(16,21,19,0.04), 0 8px 24px -12px rgba(16,21,19,0.12)',
        'card-hover': '0 4px 12px rgba(16,21,19,0.06), 0 20px 40px -16px rgba(16,21,19,0.22)'
      }
    }
  },
  plugins: [require('@tailwindcss/typography')]
};
