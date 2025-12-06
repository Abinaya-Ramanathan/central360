import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get attendance records
router.get('/', async (req, res) => {
  try {
    const { sector, month, date } = req.query;
    let query = 'SELECT * FROM attendance WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector = $${paramCount++}`;
      params.push(sector);
    }
    if (month) {
      query += ` AND EXTRACT(MONTH FROM date) = $${paramCount++}`;
      params.push(month);
    }
    if (date) {
      // Use DATE() function to ensure proper date comparison
      query += ` AND date::date = $${paramCount++}::date`;
      params.push(date);
    }

    query += ' ORDER BY date DESC, employee_name';
    console.log('Attendance query:', query);
    console.log('Attendance params:', params);
    const { rows } = await db.query(query, params);
    console.log('Attendance results:', rows.length, 'records');
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Error fetching attendance' });
  }
});

// Create or update attendance
router.post('/', async (req, res) => {
  try {
    const {
      employee_id,
      employee_name,
      sector,
      date,
      status,
      ot_hours,
      outstanding_advance,
      advance_taken,
      advance_paid,
      bulk_advance,
      bulk_advance_taken,
      bulk_advance_paid,
    } = req.body;

    // Check if attendance record already exists
    const existing = await db.query(
      'SELECT * FROM attendance WHERE employee_id = $1 AND date = $2',
      [employee_id, date]
    );

    if (existing.rows.length > 0) {
      // Update existing record
      const { rows } = await db.query(
        `UPDATE attendance SET
          status = $1, ot_hours = $2, outstanding_advance = $3, advance_taken = $4, advance_paid = $5,
          bulk_advance = $6, bulk_advance_taken = $7, bulk_advance_paid = $8
        WHERE employee_id = $9 AND date = $10
        RETURNING *`,
        [status, ot_hours || 0, outstanding_advance, advance_taken, advance_paid, bulk_advance || 0, bulk_advance_taken || 0, bulk_advance_paid || 0, employee_id, date]
      );
      res.json(rows[0]);
    } else {
      // Create new record
      const { rows } = await db.query(
        `INSERT INTO attendance (
          employee_id, employee_name, sector, date, status, ot_hours,
          outstanding_advance, advance_taken, advance_paid,
          bulk_advance, bulk_advance_taken, bulk_advance_paid
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING *`,
        [
          employee_id,
          employee_name,
          sector,
          date,
          status,
          ot_hours || 0,
          outstanding_advance || 0,
          advance_taken || 0,
          advance_paid || 0,
          bulk_advance || 0,
          bulk_advance_taken || 0,
          bulk_advance_paid || 0,
        ]
      );
      res.status(201).json(rows[0]);
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Error saving attendance' });
  }
});

// Get latest outstanding advance for an employee before a given date
// This gets the outstanding_advance from the most recent attendance record up to and including the given date
// It prioritizes records with non-zero outstanding_advance to ensure advances persist until paid off
router.get('/outstanding/:employeeId/:date', async (req, res) => {
  try {
    const { employeeId, date } = req.params;
    console.log(`[Outstanding Advance] Request for employeeId: ${employeeId}, date: ${date}`);
    
    // First, try to get the most recent record with non-zero outstanding_advance
    // This ensures that if an advance was taken and not yet paid, it will be returned
    let { rows } = await db.query(
      `SELECT outstanding_advance, date
       FROM attendance 
       WHERE employee_id = $1 AND date <= $2::date AND (outstanding_advance IS NOT NULL AND outstanding_advance > 0)
       ORDER BY date DESC 
       LIMIT 1`,
      [employeeId, date]
    );
    
    // If no non-zero record found, get the most recent record (which might be 0 or NULL)
    // This handles the case where advance was fully paid off
    if (rows.length === 0) {
      const result = await db.query(
        `SELECT outstanding_advance, date
         FROM attendance 
         WHERE employee_id = $1 AND date <= $2::date
         ORDER BY date DESC 
         LIMIT 1`,
        [employeeId, date]
      );
      rows = result.rows;
    }
    
    console.log(`[Outstanding Advance] Found ${rows.length} record(s) for employeeId: ${employeeId}, date: ${date}`);
    if (rows.length > 0) {
      console.log(`[Outstanding Advance] Record date: ${rows[0].date}, outstanding_advance: ${rows[0].outstanding_advance}`);
    }
    
    // Return the outstanding_advance from the most recent record up to and including the given date
    // This represents the cumulative outstanding as of the given date (including that date's transactions)
    const outstanding = rows.length > 0 
      ? parseFloat(rows[0].outstanding_advance) || 0 
      : 0;
    
    console.log(`[Outstanding Advance] Returning outstanding_advance: ${outstanding} for employeeId: ${employeeId}, date: ${date}`);
    res.json({ outstanding_advance: outstanding });
  } catch (err) {
    console.error('Error fetching outstanding advance:', err);
    res.status(500).json({ message: 'Error fetching outstanding advance' });
  }
});

// Get latest bulk advance for an employee before a given date
// This gets the bulk_advance from the most recent attendance record up to and including the given date
// It prioritizes records with non-zero bulk_advance to ensure advances persist until paid off
router.get('/bulk-advance/:employeeId/:date', async (req, res) => {
  try {
    const { employeeId, date } = req.params;
    console.log(`[Bulk Advance] Request for employeeId: ${employeeId}, date: ${date}`);
    
    // First, try to get the most recent record with non-zero bulk_advance
    // This ensures that if a bulk advance was taken and not yet paid, it will be returned
    let { rows } = await db.query(
      `SELECT bulk_advance, date
       FROM attendance 
       WHERE employee_id = $1 AND date <= $2::date AND (bulk_advance IS NOT NULL AND bulk_advance > 0)
       ORDER BY date DESC 
       LIMIT 1`,
      [employeeId, date]
    );
    
    // If no non-zero record found, get the most recent record (which might be 0 or NULL)
    // This handles the case where bulk advance was fully paid off
    if (rows.length === 0) {
      const result = await db.query(
        `SELECT bulk_advance, date
         FROM attendance 
         WHERE employee_id = $1 AND date <= $2::date
         ORDER BY date DESC 
         LIMIT 1`,
        [employeeId, date]
      );
      rows = result.rows;
    }
    
    console.log(`[Bulk Advance] Found ${rows.length} record(s) for employeeId: ${employeeId}, date: ${date}`);
    if (rows.length > 0) {
      console.log(`[Bulk Advance] Record date: ${rows[0].date}, bulk_advance: ${rows[0].bulk_advance}`);
    }
    
    // Return the bulk_advance from the most recent record up to and including the given date
    // This represents the cumulative bulk advance as of the given date (including that date's transactions)
    const bulkAdvance = rows.length > 0 
      ? parseFloat(rows[0].bulk_advance) || 0 
      : 0;
    
    console.log(`[Bulk Advance] Returning bulk_advance: ${bulkAdvance} for employeeId: ${employeeId}, date: ${date}`);
    res.json({ bulk_advance: bulkAdvance });
  } catch (err) {
    console.error('Error fetching bulk advance:', err);
    res.status(500).json({ message: 'Error fetching bulk advance' });
  }
});

// Bulk update attendance
router.post('/bulk', async (req, res) => {
  try {
    const { attendance_records } = req.body;

    const results = [];
    for (const record of attendance_records) {
      const {
        employee_id,
        employee_name,
        sector,
        date,
        status,
        ot_hours,
        outstanding_advance,
        advance_taken,
        advance_paid,
        bulk_advance,
        bulk_advance_taken,
        bulk_advance_paid,
      } = record;

      const existing = await db.query(
        'SELECT * FROM attendance WHERE employee_id = $1 AND date = $2',
        [employee_id, date]
      );

      if (existing.rows.length > 0) {
        const { rows } = await db.query(
          `UPDATE attendance SET
            status = $1, ot_hours = $2, outstanding_advance = $3, advance_taken = $4, advance_paid = $5,
            bulk_advance = $6, bulk_advance_taken = $7, bulk_advance_paid = $8
          WHERE employee_id = $9 AND date = $10
          RETURNING *`,
          [status, ot_hours || 0, outstanding_advance, advance_taken, advance_paid, bulk_advance || 0, bulk_advance_taken || 0, bulk_advance_paid || 0, employee_id, date]
        );
        results.push(rows[0]);
      } else {
        const { rows } = await db.query(
          `INSERT INTO attendance (
            employee_id, employee_name, sector, date, status, ot_hours,
            outstanding_advance, advance_taken, advance_paid,
            bulk_advance, bulk_advance_taken, bulk_advance_paid
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
          RETURNING *`,
          [
            employee_id,
            employee_name,
            sector,
            date,
            status,
            ot_hours || 0,
            outstanding_advance || 0,
            advance_taken || 0,
            advance_paid || 0,
            bulk_advance || 0,
            bulk_advance_taken || 0,
            bulk_advance_paid || 0,
          ]
        );
        results.push(rows[0]);
      }
    }

    res.json(results);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Error bulk updating attendance' });
  }
});

export default router;

