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
    let isMainAdmin = false;
    /** @type {string[] | null} sector codes the user can access (keyword login); null for admin */
    let sectorCodes = null;

    const passwordLower = password.toLowerCase().trim();

    // Admin: only password "surya" (case insensitive). "admin" is rejected.
    if (passwordLower === 'surya') {
      isValid = true;
      isAdmin = true;
      isMainAdmin = true;
    } else if (passwordLower === 'abinaya') {
      isValid = true;
      isAdmin = true;
      isMainAdmin = true;
    } else if (passwordLower === 'admin') {
      return res.status(401).json({ message: 'Invalid username or password' });
    } else {
      // Keyword login: map password to sector codes (main + subsector access)
      const keywordToSectorCodes = {
        cafe: ['SSC'],                    // Sri Suryaas Cafe (main + subsector)
        crusher: ['SSBM', 'SSEW'],        // Sri Surya Blue Metals, Sri Surya Engineering Works
        mahal: ['SSMMC'],                 // Sri Surya Mahal Minihall and Catering
        bunk: ['SSBP'],                   // Sri Surya Bharath Petroleum
        ricemill: ['SSR'],                // Sri Surya Ricemill
        farm: ['SSACF'],                  // Sri Suryaa Agro and Cattle Farm
      };
      const codes = keywordToSectorCodes[passwordLower];
      if (codes && Array.isArray(codes) && codes.length > 0) {
        isValid = true;
        sectorCodes = codes;
      }
    }

    if (!isValid) {
      return res.status(401).json({ message: 'Invalid username or password' });
    }

    const token = jwt.sign(
      { sub: username, company: company || null, isAdmin, isMainAdmin, sectorCodes },
      process.env.JWT_SECRET || 'dev-secret',
      { expiresIn: process.env.JWT_EXPIRES_IN || '1d' }
    );

    res.json({
      token,
      username,
      isAdmin,
      isMainAdmin,
      sectorCodes: sectorCodes,
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ message: 'Login error', error: process.env.NODE_ENV === 'development' ? err.message : undefined });
  }
});

export default router;


