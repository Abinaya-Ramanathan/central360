import { Router } from 'express';
import jwt from 'jsonwebtoken';
import db from '../db.js';

const router = Router();

router.post('/login', async (req, res) => {
  const { company, username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ message: 'username and password are required' });
  }

  try {
    let isValid = false;
    let isAdmin = false;
    let sectorCode = null;

    // Check for admin login - based on PASSWORD, not username
    // Admin privileges: password is "admin" OR "abinaya" (case insensitive) - username doesn't matter
    // Main Admin (delete privileges): password is "abinaya" (case insensitive) - username doesn't matter
    const passwordLower = password.toLowerCase();
    
    if (passwordLower === 'admin' || passwordLower === 'abinaya') {
      isValid = true;
      isAdmin = true;
    } else {
      // Check if password matches a sector code
      const sectorResult = await db.query(
        'SELECT code FROM sectors WHERE code = $1',
        [password.toUpperCase()]
      );
      
      if (sectorResult.rows.length > 0) {
        isValid = true;
        isAdmin = false;
        sectorCode = sectorResult.rows[0].code;
      }
    }

    if (!isValid) {
      return res.status(401).json({ message: 'Invalid username or password' });
    }

    // Check if main admin - based on PASSWORD being "abinaya" (case insensitive)
    const isMainAdmin = passwordLower === 'abinaya';

    const token = jwt.sign(
      { sub: username, company: company || null, isAdmin, isMainAdmin, sectorCode },
      process.env.JWT_SECRET || 'dev-secret',
      { expiresIn: process.env.JWT_EXPIRES_IN || '1d' }
    );

    res.json({ 
      token,
      username,
      isAdmin,
      isMainAdmin,
      sectorCode 
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ message: 'Login error', error: process.env.NODE_ENV === 'development' ? err.message : undefined });
  }
});

export default router;


