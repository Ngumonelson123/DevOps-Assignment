const express = require('express');
const { Pool } = require('pg');

const app = express();
const port = 3000;

const pool = new Pool({
  host: process.env.POSTGRES_HOST || 'localhost',
  user: process.env.POSTGRES_USER || 'devops',
  database: process.env.POSTGRES_DB || 'devopsdb',
  password: process.env.POSTGRES_PASSWORD || 'secret',
  port: process.env.POSTGRES_PORT || 5432,
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

app.get('/db', async (req, res) => {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT NOW()');
    client.release();
    res.json({
      message: 'Database connection successful!',
      database: process.env.POSTGRES_DB || 'devopsdb',
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