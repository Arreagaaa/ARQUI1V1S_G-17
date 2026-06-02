export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      boxShadow: {
        glow: '0 0 0 1px rgba(16, 185, 129, 0.18), 0 20px 45px rgba(6, 78, 59, 0.16)',
      },
      backgroundImage: {
        'dashboard-grid':
          'radial-gradient(circle at 1px 1px, rgba(148, 163, 184, 0.18) 1px, transparent 0)',
      },
    },
  },
  plugins: [],
};
