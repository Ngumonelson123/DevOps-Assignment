const express = require('express');
const { Pool } = require('pg');

const app = express();
const port = 3000;

// Request counter for metrics
let requestCount = 0;
let dbConnections = 0;

// Structured logging function
const log = (level, data) => {
  console.log(JSON.stringify({
    level,
    timestamp: new Date().toISOString(),
    service: 'nodejs-express',
    ...data
  }));
};

const pool = new Pool({
  host: process.env.POSTGRES_HOST,
  user: process.env.POSTGRES_USER,
  database: process.env.POSTGRES_DB,
  password: process.env.POSTGRES_PASSWORD,
  port: process.env.POSTGRES_PORT
});

app.get('/', (req, res) => {
  requestCount++;
  
  log('info', {
    event: 'request',
    endpoint: '/',
    method: req.method,
    ip: req.ip
  });
  
  res.json({
    message: 'Hello from Node.js!',
    timestamp: new Date().toISOString(),
    service: 'nodejs-express'
  });
});

app.get('/health', (req, res) => {
  log('info', {
    event: 'health_check',
    status: 'healthy'
  });
  
  res.json({ status: 'healthy', service: 'nodejs-express' });
});

app.get('/metrics', (req, res) => {
  const metrics = `# HELP nodejs_app_requests_total Total requests
# TYPE nodejs_app_requests_total counter
nodejs_app_requests_total ${requestCount}

# HELP nodejs_app_up Application status
# TYPE nodejs_app_up gauge
nodejs_app_up 1

# HELP nodejs_app_db_connections Database connections
# TYPE nodejs_app_db_connections gauge
nodejs_app_db_connections ${dbConnections}

# HELP nodejs_app_info Application info
# TYPE nodejs_app_info gauge
nodejs_app_info{version="1.0",service="nodejs-express"} 1
`;
  res.set('Content-Type', 'text/plain');
  res.send(metrics);
});

app.get('/db', async (req, res) => {
  log('info', {
    event: 'db_connection_attempt',
    database: process.env.POSTGRES_DB
  });
  
  try {
    dbConnections++;
    const client = await pool.connect();
    const result = await client.query('SELECT NOW()');
    client.release();
    dbConnections--;
    
    log('info', {
      event: 'db_connection_success',
      database: process.env.POSTGRES_DB
    });
    
    res.json({
      message: 'Database connection successful!',
      database: process.env.POSTGRES_DB,
      timestamp: new Date().toISOString(),
      db_time: result.rows[0].now
    });
  } catch (err) {
    dbConnections--;
    
    log('error', {
      event: 'db_connection_failed',
      error: err.message
    });
    
    res.status(500).json({
      error: `Database connection failed: ${err.message}`,
      timestamp: new Date().toISOString()
    });
  }
});

app.listen(port, () => {
  log('info', {
    event: 'app_startup',
    port: port
  });
});