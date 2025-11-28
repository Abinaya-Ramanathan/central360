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
    const uploadDir = path.join(__dirname, '../../uploads/purchases');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'purchase-' + uniqueSuffix + path.extname(file.originalname));
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

// For multiple file uploads
const uploadMultiple = upload.array('photos', 10); // Allow up to 10 photos

// Get company purchase details
router.get('/', async (req, res) => {
  try {
    const { sector, date, month } = req.query;
    let query = `SELECT 
      id, sector_code, item_name, shop_name, purchase_details, purchase_amount,
      amount_paid, credit, details,
      COALESCE(balance_paid, 0) as balance_paid,
      TO_CHAR(purchase_date, 'YYYY-MM-DD') as purchase_date,
      TO_CHAR(balance_paid_date, 'YYYY-MM-DD') as balance_paid_date,
      created_at, updated_at
      FROM company_purchase_details WHERE 1=1`;
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    if (date) {
      query += ` AND purchase_date = $${paramCount++}::date`;
      params.push(date);
    }

    if (month) {
      query += ` AND TO_CHAR(purchase_date, 'YYYY-MM') = $${paramCount++}`;
      params.push(month);
    }

    query += ' ORDER BY purchase_date DESC, created_at DESC';
    const { rows } = await db.query(query, params);
    
    // Get photos for each purchase
    for (const row of rows) {
      const photosResult = await db.query(
        'SELECT id, image_url, created_at FROM company_purchase_photos WHERE purchase_id = $1 ORDER BY created_at ASC',
        [row.id]
      );
      row.photos = photosResult.rows;
    }
    
    res.json(rows);
  } catch (err) {
    console.error('Error fetching company purchase details:', err);
    res.status(500).json({ message: 'Error fetching company purchase details' });
  }
});

// Get credit details (people with credit > 0)
router.get('/credits', async (req, res) => {
  try {
    const { sector } = req.query;
    let query = `SELECT 
      id, sector_code, item_name, shop_name, purchase_details, purchase_amount,
      amount_paid, credit, details,
      COALESCE(balance_paid, 0) as balance_paid,
      TO_CHAR(purchase_date, 'YYYY-MM-DD') as purchase_date,
      TO_CHAR(balance_paid_date, 'YYYY-MM-DD') as balance_paid_date,
      created_at, updated_at
      FROM company_purchase_details WHERE credit > 0`;
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY purchase_date DESC, created_at DESC';
    const { rows } = await db.query(query, params);
    
    // Get photos and balance payments for each purchase
    for (const row of rows) {
      const photosResult = await db.query(
        'SELECT id, image_url, created_at FROM company_purchase_photos WHERE purchase_id = $1 ORDER BY created_at ASC',
        [row.id]
      );
      row.photos = photosResult.rows;
      
      // Get balance payments for this purchase
      const paymentsResult = await db.query(
        `SELECT id, balance_paid, TO_CHAR(balance_paid_date, 'YYYY-MM-DD') as balance_paid_date, 
         details, overall_balance, created_at, updated_at 
         FROM company_purchase_balance_payments 
         WHERE purchase_id = $1 
         ORDER BY created_at ASC`,
        [row.id]
      );
      row.balance_payments = paymentsResult.rows;
    }
    
    res.json(rows);
  } catch (err) {
    console.error('Error fetching credit details from company purchases:', err);
    res.status(500).json({ message: 'Error fetching credit details' });
  }
});

// Create or update company purchase details
router.post('/', async (req, res) => {
  try {
    const {
      id,
      sector_code,
      item_name,
      shop_name,
      purchase_details,
      purchase_amount,
      amount_paid,
      credit,
      details,
      balance_paid,
      balance_paid_date,
      purchase_date,
    } = req.body;

    // All fields are optional now
    const purchaseDate = purchase_date || new Date().toISOString().split('T')[0];

    if (id) {
      // Update existing record
      const { rows } = await db.query(
        `UPDATE company_purchase_details SET
          sector_code = $1,
          item_name = $2,
          shop_name = $3,
          purchase_details = $4,
          purchase_amount = $5,
          amount_paid = $6,
          credit = $7,
          details = $8,
          balance_paid = $9,
          balance_paid_date = $10,
          purchase_date = $11,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = $12
        RETURNING *`,
        [
          sector_code || null,
          item_name || null,
          shop_name || null,
          purchase_details || null,
          purchase_amount || 0,
          amount_paid || 0,
          credit || 0,
          details || null,
          balance_paid || 0,
          balance_paid_date || null,
          purchaseDate,
          id,
        ]
      );

      if (rows.length === 0) {
        return res.status(404).json({ message: 'Company purchase details not found' });
      }

      res.json(rows[0]);
    } else {
      // Create new record
      const { rows } = await db.query(
        `INSERT INTO company_purchase_details (
          sector_code, item_name, shop_name, purchase_details, purchase_amount,
          amount_paid, credit, details, balance_paid, balance_paid_date, purchase_date
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        RETURNING *`,
        [
          sector_code || null,
          item_name || null,
          shop_name || null,
          purchase_details || null,
          purchase_amount || 0,
          amount_paid || 0,
          credit || 0,
          details || null,
          balance_paid || 0,
          balance_paid_date || null,
          purchaseDate,
        ]
      );

      res.status(201).json(rows[0]);
    }
  } catch (err) {
    console.error('Error saving company purchase details:', err);
    res.status(500).json({
      message: 'Error saving company purchase details',
      error: err.message,
    });
  }
});

// Upload multiple photos for a purchase
router.post('/:id/photos', uploadMultiple, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Check if purchase exists
    const purchaseCheck = await db.query('SELECT id FROM company_purchase_details WHERE id = $1', [id]);
    if (purchaseCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Company purchase not found' });
    }

    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ message: 'No photos provided' });
    }

    const photos = [];
    for (const file of req.files) {
      const imageUrl = `/uploads/purchases/${file.filename}`;
      const result = await db.query(
        'INSERT INTO company_purchase_photos (purchase_id, image_url) VALUES ($1, $2) RETURNING *',
        [id, imageUrl]
      );
      photos.push(result.rows[0]);
    }

    res.status(201).json({ photos });
  } catch (err) {
    console.error('Error uploading photos:', err);
    res.status(500).json({
      message: 'Error uploading photos',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Get photos for a purchase
router.get('/:id/photos', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await db.query(
      'SELECT id, image_url, created_at FROM company_purchase_photos WHERE purchase_id = $1 ORDER BY created_at ASC',
      [id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching photos:', err);
    res.status(500).json({ message: 'Error fetching photos' });
  }
});

// Delete a photo
router.delete('/photos/:photoId', async (req, res) => {
  try {
    const { photoId } = req.params;
    
    // Get photo info before deleting
    const photoResult = await db.query('SELECT image_url FROM company_purchase_photos WHERE id = $1', [photoId]);
    if (photoResult.rows.length === 0) {
      return res.status(404).json({ message: 'Photo not found' });
    }

    // Delete file
    if (photoResult.rows[0].image_url) {
      const photoPath = path.join(__dirname, '../../', photoResult.rows[0].image_url);
      if (fs.existsSync(photoPath)) {
        fs.unlinkSync(photoPath);
      }
    }

    await db.query('DELETE FROM company_purchase_photos WHERE id = $1', [photoId]);
    res.status(200).json({ message: 'Photo deleted successfully' });
  } catch (err) {
    console.error('Error deleting photo:', err);
    res.status(500).json({
      message: 'Error deleting photo',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete company purchase details
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Delete photos first
    const photosResult = await db.query('SELECT image_url FROM company_purchase_photos WHERE purchase_id = $1', [id]);
    for (const photo of photosResult.rows) {
      if (photo.image_url) {
        const photoPath = path.join(__dirname, '../../', photo.image_url);
        if (fs.existsSync(photoPath)) {
          fs.unlinkSync(photoPath);
        }
      }
    }
    await db.query('DELETE FROM company_purchase_photos WHERE purchase_id = $1', [id]);
    
    const { rows } = await db.query(
      'DELETE FROM company_purchase_details WHERE id = $1 RETURNING *',
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: 'Company purchase details not found' });
    }

    res.status(200).json({ message: 'Company purchase details deleted successfully' });
  } catch (err) {
    console.error('Error deleting company purchase details:', err);
    res.status(500).json({
      message: 'Error deleting company purchase details',
      error: err.message,
    });
  }
});

// Get balance payments for a purchase
router.get('/:id/balance-payments', async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await db.query(
      `SELECT id, balance_paid, TO_CHAR(balance_paid_date, 'YYYY-MM-DD') as balance_paid_date, 
       details, overall_balance, created_at, updated_at 
       FROM company_purchase_balance_payments 
       WHERE purchase_id = $1 
       ORDER BY created_at ASC`,
      [id]
    );
    res.json(rows);
  } catch (err) {
    console.error('Error fetching balance payments:', err);
    res.status(500).json({ message: 'Error fetching balance payments' });
  }
});

// Create or update a balance payment
router.post('/balance-payments', async (req, res) => {
  try {
    const {
      id,
      purchase_id,
      balance_paid,
      balance_paid_date,
      details,
      overall_balance,
    } = req.body;

    if (!purchase_id) {
      return res.status(400).json({ message: 'purchase_id is required' });
    }

    if (id) {
      // Update existing balance payment
      const { rows } = await db.query(
        `UPDATE company_purchase_balance_payments SET
          balance_paid = $1,
          balance_paid_date = $2,
          details = $3,
          overall_balance = $4,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = $5
        RETURNING id, balance_paid, TO_CHAR(balance_paid_date, 'YYYY-MM-DD') as balance_paid_date, 
                   details, overall_balance, created_at, updated_at`,
        [
          balance_paid || 0,
          balance_paid_date || null,
          details || null,
          overall_balance || 0,
          id,
        ]
      );

      if (rows.length === 0) {
        return res.status(404).json({ message: 'Balance payment not found' });
      }

      res.json(rows[0]);
    } else {
      // Create new balance payment
      const { rows } = await db.query(
        `INSERT INTO company_purchase_balance_payments (
          purchase_id, balance_paid, balance_paid_date, details, overall_balance
        ) VALUES ($1, $2, $3, $4, $5)
        RETURNING id, balance_paid, TO_CHAR(balance_paid_date, 'YYYY-MM-DD') as balance_paid_date, 
                   details, overall_balance, created_at, updated_at`,
        [
          purchase_id,
          balance_paid || 0,
          balance_paid_date || null,
          details || null,
          overall_balance || 0,
        ]
      );

      res.status(201).json(rows[0]);
    }
  } catch (err) {
    console.error('Error saving balance payment:', err);
    res.status(500).json({
      message: 'Error saving balance payment',
      error: err.message,
    });
  }
});

// Delete a balance payment
router.delete('/balance-payments/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await db.query(
      'DELETE FROM company_purchase_balance_payments WHERE id = $1 RETURNING *',
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: 'Balance payment not found' });
    }

    res.status(200).json({ message: 'Balance payment deleted successfully' });
  } catch (err) {
    console.error('Error deleting balance payment:', err);
    res.status(500).json({
      message: 'Error deleting balance payment',
      error: err.message,
    });
  }
});

export default router;
