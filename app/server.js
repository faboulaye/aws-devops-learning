'use strict';

const path = require('path');
const os = require('os');
const express = require('express');

// Load version from package.json
const pkg = require('../package.json');

const app = express();

// Serve static files from public directory (moved inside app/public)
const publicDir = path.join(__dirname, 'public');
app.use(express.static(publicDir));

// Health endpoint
app.get('/healthz', (req, res) => {
  res.json({ status: 'OK', time: new Date().toISOString() });
});

// Info endpoint
app.get('/api/info', (req, res) => {
  res.json({ hostname: os.hostname(), version: pkg.version });
});

// Fallback to index.html for root
app.get('/', (req, res) => {
  res.sendFile(path.join(publicDir, 'index.html'));
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  /* eslint-disable no-console */
  console.log(`Server listening on port ${port}`);
});


