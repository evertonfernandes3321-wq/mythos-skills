// app.js — SYNTHETIC, INTENTIONALLY INSECURE demo Express app.
// Purpose: illustrate common vulnerabilities for the Mythos skills demo. DO NOT DEPLOY.
const express = require('express');
const crypto = require('crypto');
const { pool, rawFindUserByEmail } = require('./db');

const app = express();
app.use(express.json());

// VULN: hardcoded secret used to sign tokens (should be an env var / secret manager)
const JWT_SECRET = 'demo-signing-key-do-not-use';

// VULN: weak password hashing — MD5, unsalted, fast and reversible via rainbow tables
function hashPassword(plain) {
  return crypto.createHash('md5').update(plain).digest('hex');
}

// Login: looks up the user with a concatenated SQL string (SQL injection via db.js sink).
// No rate limiting on this endpoint — brute force / credential stuffing is unthrottled.
app.post('/login', (req, res) => {
  const { email, password } = req.body;
  rawFindUserByEmail(email, (err, rows) => {
    if (err) return res.status(500).json({ error: 'db error' });
    const user = rows && rows[0];
    if (user && user.pass_md5 === hashPassword(password)) {
      return res.json({ token: JWT_SECRET + ':' + user.id });
    }
    return res.status(401).json({ error: 'invalid credentials' });
  });
});

// VULN: product search reflects the raw query term back into an HTML response
// with no output escaping (reflected XSS). Also concatenates input into SQL.
app.get('/search', (req, res) => {
  const term = req.query.q || '';
  const sql = "SELECT id, name FROM products WHERE name LIKE '%" + term + "%'";
  pool.query(sql, (err, rows) => {
    if (err) return res.status(500).send('db error');
    res.set('Content-Type', 'text/html');
    res.send('<h1>Results for ' + term + '</h1><ul>' +
      (rows || []).map((r) => '<li>' + r.name + '</li>').join('') + '</ul>');
  });
});

// VULN: admin route performs NO authorization check — any caller can read all users
// (Broken Function Level Authorization + IDOR-style mass data exposure).
app.get('/admin/users', (req, res) => {
  pool.query('SELECT id, email, role, pass_md5 FROM users', (err, rows) => {
    if (err) return res.status(500).json({ error: 'db error' });
    res.json(rows); // leaks every user's email, role and password hash
  });
});

// VULN: deletes any user by id with no auth and no ownership check (BOLA).
app.delete('/users/:id', (req, res) => {
  pool.query('DELETE FROM users WHERE id = ?', [req.params.id], (err) => {
    if (err) return res.status(500).json({ error: 'db error' });
    res.json({ deleted: req.params.id });
  });
});

app.listen(3000, () => console.log('demo app on :3000'));
