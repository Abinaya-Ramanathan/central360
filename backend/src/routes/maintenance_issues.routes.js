import { Router } from 'express';
import db from '../db.js';
import multer from 'multer';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const router = Router();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../../uploads/maintenance');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'maintenance-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);
    if (mimetype && extname) {
      return cb(null, true);
    }
    cb(new Error('Only image files are allowed'));
  }
});

// Get maintenance issues
router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;
    let query = `
      SELECT mi.*, s.name as sector_name 
      FROM maintenance_issues mi
      JOIN sectors s ON mi.sector_code = s.code
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND mi.sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY mi.date_created DESC, mi.created_at DESC';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching maintenance issues:', err);
    res.status(500).json({ message: 'Error fetching maintenance issues' });
  }
});

// Create maintenance issue
router.post('/', upload.single('image'), async (req, res) => {
  try {
    const {
      issue_description,
      date_created,
      status,
      date_resolved,
      sector_code,
    } = req.body;

    if (!sector_code) {
      return res.status(400).json({ message: 'Sector code is required' });
    }

    // Check if sector exists
    const sectorCheck = await db.query('SELECT code FROM sectors WHERE code = $1', [sector_code]);
    if (sectorCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Sector not found' });
    }

    // Handle image upload
    let imageUrl = null;
    if (req.file) {
      imageUrl = `/uploads/maintenance/${req.file.filename}`;
    }

    const { rows } = await db.query(
      `INSERT INTO maintenance_issues (
        issue_description, date_created, image_url, status, date_resolved, sector_code
      ) VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *`,
      [
        issue_description || null,
        date_created || null,
        imageUrl,
        status || 'Not resolved',
        date_resolved || null,
        sector_code,
      ]
    );

    // Join with sectors to get sector name
    const result = await db.query(
      `SELECT mi.*, s.name as sector_name 
       FROM maintenance_issues mi
       JOIN sectors s ON mi.sector_code = s.code
       WHERE mi.id = $1`,
      [rows[0].id]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating maintenance issue:', err);
    res.status(500).json({
      message: 'Error creating maintenance issue',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Update maintenance issue
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const {
      issue_description,
      date_created,
      status,
      date_resolved,
      sector_code,
    } = req.body;

    const { rows } = await db.query(
      `UPDATE maintenance_issues SET
        issue_description = $1, date_created = $2, status = $3,
        date_resolved = $4, sector_code = $5, updated_at = CURRENT_TIMESTAMP
      WHERE id = $6
      RETURNING *`,
      [
        issue_description || null,
        date_created || null,
        status || 'Not resolved',
        date_resolved || null,
        sector_code,
        id,
      ]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: 'Maintenance issue not found' });
    }

    // Join with sectors to get sector name
    const result = await db.query(
      `SELECT mi.*, s.name as sector_name 
       FROM maintenance_issues mi
       JOIN sectors s ON mi.sector_code = s.code
       WHERE mi.id = $1`,
      [id]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating maintenance issue:', err);
    res.status(500).json({
      message: 'Error updating maintenance issue',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete maintenance issue
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    // Get the issue to delete associated image
    const issueResult = await db.query('SELECT image_url FROM maintenance_issues WHERE id = $1', [id]);
    
    if (issueResult.rows.length === 0) {
      return res.status(404).json({ message: 'Maintenance issue not found' });
    }

    // Delete image file if exists
    if (issueResult.rows[0].image_url) {
      const imagePath = path.join(__dirname, '../../', issueResult.rows[0].image_url);
      if (fs.existsSync(imagePath)) {
        fs.unlinkSync(imagePath);
      }
    }

    const result = await db.query('DELETE FROM maintenance_issues WHERE id = $1 RETURNING *', [id]);

    res.status(200).json({ message: 'Maintenance issue deleted successfully' });
  } catch (err) {
    console.error('Error deleting maintenance issue:', err);
    res.status(500).json({
      message: 'Error deleting maintenance issue',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

