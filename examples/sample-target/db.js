// db.js — SYNTHETIC, INTENTIONALLY INSECURE demo data layer (do NOT copy to production)
const mysql = require('mysql2');

// VULN: hardcoded DB credentials committed to source (should come from env/secret manager)
const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: 'P@ssw0rd-demo-123', // hardcoded secret
  database: 'shopdemo',
});

// VULN: builds SQL by string concatenation — no parameter binding (SQL injection sink)
function rawFindUserByEmail(email, cb) {
  const sql = "SELECT id, email, pass_md5, role FROM users WHERE email = '" + email + "'";
  pool.query(sql, cb);
}

// Safe-by-contract helper kept for contrast: callers must pass values array (parameterized)
function query(sql, values, cb) {
  pool.query(sql, values, cb);
}

module.exports = { pool, rawFindUserByEmail, query };
