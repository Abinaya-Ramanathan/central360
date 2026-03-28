import { Router } from 'express';
import db from '../db.js';

const router = Router();

// GET note for one sector (empty body if none yet)
router.get('/:sectorCode', async (req, res) => {
  try {
    const { sectorCode } = req.params;
    const { rows } = await db.query(
      'SELECT sector_code, body, updated_at FROM sector_notes WHERE sector_code = $1',
      [sectorCode]
    );
    if (rows.length === 0) {
      return res.json({ sector_code: sectorCode, body: '', updated_at: null });
    }
    res.json(rows[0]);
  } catch (err) {
    console.error('Error fetching sector notes:', err);
    res.status(500).json({ message: 'Error fetching sector notes' });
  }
});

// Upsert only — no DELETE route (notes are not removable via API)
router.put('/:sectorCode', async (req, res) => {
  try {
    const { sectorCode } = req.params;
    const body = typeof req.body?.body === 'string' ? req.body.body : '';

    const sec = await db.query('SELECT 1 FROM sectors WHERE code = $1', [sectorCode]);
    if (sec.rows.length === 0) {
      return res.status(400).json({ message: 'Unknown sector code' });
    }

    const { rows } = await db.query(
      `INSERT INTO sector_notes (sector_code, body, updated_at)
       VALUES ($1, $2, CURRENT_TIMESTAMP)
       ON CONFLICT (sector_code) DO UPDATE SET
         body = EXCLUDED.body,
         updated_at = CURRENT_TIMESTAMP
       RETURNING sector_code, body, updated_at`,
      [sectorCode, body]
    );
    res.json(rows[0]);
  } catch (err) {
    console.error('Error saving sector notes:', err);
    res.status(500).json({ message: 'Error saving sector notes' });
  }
});

export default router;
