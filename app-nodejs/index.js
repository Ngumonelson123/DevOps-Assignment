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

app.get('/', async (req, res) => {
  try {
    const client = await pool.connect();
    const result = await client.query("SELECT NOW()");
    client.release();
    res.send('Hello from Node.js + PostgreSQL is working!');
  } catch (err) {
    res.status(500).send('Error connecting to the database: ' + err.message);
  }
});
app.listen(port, () => {
  console.log(`Node.js app listening at http://localhost:${port}`);
});