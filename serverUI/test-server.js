const express = require('express');
const path = require('path');

const app = express();

// Configurazione da variabili d'ambiente
const port = process.env.PORT || 5000;
const dbPath = process.env.DB_PATH || './database';

// Middleware per parsing JSON
app.use(express.json());

// Log di avvio
console.log('='.repeat(50));
console.log(`🚀 Server di test per Server Manager UI`);
console.log(`📅 Avviato: ${new Date().toISOString()}`);
console.log(`🌐 Porta: ${port}`);
console.log(`💾 Database path: ${dbPath}`);
console.log('='.repeat(50));

// Route principale
app.get('/', (req, res) => {
  const responseData = {
    message: '✅ Server di test funzionante',
    port: port,
    dbPath: dbPath,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: {
      node_version: process.version,
      platform: process.platform,
      pid: process.pid
    }
  };
  
  console.log(`📊 GET / - Client: ${req.ip}`);
  res.json(responseData);
});

// Route per informazioni server
app.get('/info', (req, res) => {
  console.log(`ℹ️  GET /info - Richiesta informazioni server`);
  res.json({
    server_name: 'Test Server per Server Manager',
    version: '1.0.0',
    capabilities: ['basic-http', 'json-api', 'health-check'],
    status: 'running'
  });
});

// Route per simulare carico di lavoro
app.get('/work', (req, res) => {
  console.log(`⚙️  GET /work - Simulazione lavoro pesante`);
  
  // Simula lavoro CPU-intensivo
  const iterations = parseInt(req.query.iterations) || 1000000;
  let result = 0;
  
  for (let i = 0; i < iterations; i++) {
    result += Math.sqrt(i);
  }
  
  console.log(`✨ Lavoro completato: ${iterations} iterazioni`);
  res.json({
    result: result,
    iterations: iterations,
    duration_ms: Date.now() - req.query.start || 0
  });
});

// Route per testare errori
app.get('/error', (req, res) => {
  console.error('❌ ERROR /error - Errore simulato');
  res.status(500).json({
    error: 'Questo è un errore di test',
    timestamp: new Date().toISOString()
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Avvio server
const server = app.listen(port, () => {
  console.log(`✅ Server HTTP attivo sulla porta ${port}`);
  console.log(`🏥 Health check: http://localhost:${port}/health`);
  console.log(`📡 API info: http://localhost:${port}/info`);
  
  // Log periodici per testare la cattura dei log
  let logCounter = 1;
  const logInterval = setInterval(() => {
    console.log(`📝 Log periodico #${logCounter} - ${new Date().toLocaleString()}`);
    logCounter++;
    
    if (logCounter > 100) {
      console.log('🔄 Reset contatore log');
      logCounter = 1;
    }
  }, 10000); // Ogni 10 secondi
  
  // Cleanup interval on server close
  server.on('close', () => {
    clearInterval(logInterval);
  });
});

// Gestione graceful shutdown
function gracefulShutdown(signal) {
  console.log(`\n🛑 Ricevuto segnale ${signal}, arresto graceful...`);
  
  server.close(() => {
    console.log('✅ Server HTTP chiuso');
    console.log('👋 Arrivederci!');
    process.exit(0);
  });
  
  // Forza uscita dopo 5 secondi se il server non si chiude
  setTimeout(() => {
    console.error('⚠️  Timeout nella chiusura, uscita forzata');
    process.exit(1);
  }, 5000);
}

// Handler per segnali di terminazione
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Handler per errori non catturati
process.on('uncaughtException', (error) => {
  console.error('💥 Errore non catturato:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('⚡ Promise rejection non gestita:', reason);
});

// Log delle variabili d'ambiente interessanti
console.log('\n🔧 Configurazione ambiente:');
console.log(`   NODE_ENV: ${process.env.NODE_ENV || 'non definito'}`);
console.log(`   PORT: ${process.env.PORT || 'default (3000)'}`);
console.log(`   DB_PATH: ${process.env.DB_PATH || 'default (./database)'}`);
console.log('');