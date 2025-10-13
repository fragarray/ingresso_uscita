// Configurazione del server
module.exports = {
  // Porta del server
  PORT: process.env.PORT || 3000,
  
  // Database
  DB_PATH: process.env.DB_PATH || './database.db',
  
  // Reports
  REPORTS_DIR: process.env.REPORTS_DIR || './reports',
  
  // Geofencing
  GEOFENCE_RADIUS_METERS: 100,
  
  // Admin di default
  DEFAULT_ADMIN: {
    name: 'Admin',
    email: 'admin@example.com',
    password: 'admin123'
  }
};
