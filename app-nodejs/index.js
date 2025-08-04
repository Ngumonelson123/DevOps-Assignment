const express = require('express');
const { Pool } = require('pg');

const app = express();
const port = 3000;

const pool = new Pool({
  host: process.env.POSTGRES_HOST,
  user: process.env.POSTGRES_USER,
  database: process.env.POSTGRES_DB,
  password: process.env.POSTGRES_PASSWORD,
  port: process.env.POSTGRES_PORT
});

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from Node.js!',
    timestamp: new Date().toISOString(),
    service: 'nodejs-express'
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'nodejs-express' });
});

app.get('/metrics', (req, res) => {
  const metrics = `# HELP nodejs_app_requests_total Total requests
# TYPE nodejs_app_requests_total counter
nodejs_app_requests_total{method="GET",endpoint="/"} ${Date.now() % 1000}

# HELP nodejs_app_up Application status
# TYPE nodejs_app_up gauge
nodejs_app_up 1

# HELP nodejs_app_response_time_seconds Response time
# TYPE nodejs_app_response_time_seconds histogram
nodejs_app_response_time_seconds_bucket{le="0.1"} 1
nodejs_app_response_time_seconds_bucket{le="0.5"} 1
nodejs_app_response_time_seconds_bucket{le="1.0"} 1
nodejs_app_response_time_seconds_bucket{le="+Inf"} 1
nodejs_app_response_time_seconds_count 1
nodejs_app_response_time_seconds_sum 0.1
`;
  res.set('Content-Type', 'text/plain');
  res.send(metrics);
});

app.get('/db', async (req, res) => {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT NOW()');
    client.release();
    res.json({
      message: 'Database connection successful!',
      database: process.env.POSTGRES_DB,
      timestamp: new Date().toISOString(),
      db_time: result.rows[0].now
    });
  } catch (err) {
    res.status(500).json({
      error: `Database connection failed: ${err.message}`,
      timestamp: new Date().toISOString()
    });
  }
});

app.listen(port, () => {
  console.log(`Node.js app listening at http://localhost:${port}`);
});