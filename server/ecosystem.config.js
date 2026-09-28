module.exports = {
  apps: [
    {
      name: 'rayando',
      script: 'index.js',
      // Cluster mode: scales automatically across all available CPU cores when Redis is enabled
      // Defaults to 1 instance without Redis, or 'max' if PM2_INSTANCES is set
      instances: process.env.PM2_INSTANCES ? (process.env.PM2_INSTANCES === 'max' ? 'max' : parseInt(process.env.PM2_INSTANCES, 10)) : 1,
      exec_mode: process.env.PM2_INSTANCES ? 'cluster' : 'fork',
      env: {
        NODE_ENV: 'production',
        PORT: 3001,
      },
      // Restart worker if memory exceeds 512MB to prevent memory leaks
      max_memory_restart: '512M',
      // Zero downtime reload configuration
      listen_timeout: 8000,
      kill_timeout: 4000,
      restart_delay: 2000,
    },
  ],
};
