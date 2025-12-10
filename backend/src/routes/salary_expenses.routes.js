import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get salary expenses
router.get('/', async (req, res) => {
  try {
    const startTime = Date.now();
    const { sector, week_start, week_end, employee_id } = req.query;
    // Optimized: Only select needed columns
    let query = 'SELECT id, employee_id, employee_name, sector, week_start_date, week_end_date, outstanding_advance, days_present, estimated_salary, salary_issued, salary_issued_date, advance_deducted, selected_dates FROM salary_expenses WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector = $${paramCount++}`;
      params.push(sector);
    }
    if (week_start) {
      query += ` AND week_start_date >= $${paramCount++}`;
      params.push(week_start);
    }
    if (week_end) {
      query += ` AND week_end_date <= $${paramCount++}`;
      params.push(week_end);
    }
    if (employee_id) {
      query += ` AND employee_id = $${paramCount++}`;
      params.push(employee_id);
    }

    query += ' ORDER BY week_start_date DESC, employee_name';
    const { rows } = await db.query(query, params);
    const duration = Date.now() - startTime;
    console.log(`[Performance] Salary expenses query took ${duration}ms, returned ${rows.length} records`);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching salary expenses:', err);
    res.status(500).json({ message: 'Error fetching salary expenses' });
  }
});

// Create or update salary expense (supports multiple entries per month)
router.post('/', async (req, res) => {
  try {
    const {
      id,
      employee_id,
      employee_name,
      sector,
      week_start_date,
      week_end_date,
      outstanding_advance,
      days_present,
      estimated_salary,
      advance_deducted,
      salary_issued,
      salary_issued_date,
      selected_dates,
    } = req.body;

    let rows;
    
    // If ID is provided, update existing record
    if (id) {
      const result = await db.query(
        `UPDATE salary_expenses SET
          employee_id = $1, employee_name = $2, sector = $3, week_start_date = $4, week_end_date = $5,
          outstanding_advance = $6, days_present = $7, estimated_salary = $8,
          advance_deducted = $9, salary_issued = $10, salary_issued_date = $11, selected_dates = $12,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = $13
        RETURNING *`,
        [
          employee_id,
          employee_name,
          sector,
          week_start_date,
          week_end_date,
          outstanding_advance || 0,
          days_present || 0,
          estimated_salary || 0,
          advance_deducted || 0,
          salary_issued || 0,
          salary_issued_date || null,
          selected_dates ? JSON.stringify(selected_dates) : null,
          id,
        ]
      );
      rows = result.rows;
      if (rows.length === 0) {
        return res.status(404).json({ message: 'Salary expense not found' });
      }
    } else {
      // Create new record
      const result = await db.query(
        `INSERT INTO salary_expenses (
          employee_id, employee_name, sector, week_start_date, week_end_date,
          outstanding_advance, days_present, estimated_salary,
          advance_deducted, salary_issued, salary_issued_date, selected_dates
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING *`,
        [
          employee_id,
          employee_name,
          sector,
          week_start_date,
          week_end_date,
          outstanding_advance || 0,
          days_present || 0,
          estimated_salary || 0,
          advance_deducted || 0,
          salary_issued || 0,
          salary_issued_date || null,
          selected_dates ? JSON.stringify(selected_dates) : null,
        ]
      );
      rows = result.rows;
    }

    // If advance was deducted, update the outstanding advance in attendance records
    if (advance_deducted && advance_deducted > 0) {
      try {
        // Get the latest attendance record for this employee
        const latestAttendance = await db.query(
          `SELECT id, outstanding_advance, date 
           FROM attendance 
           WHERE employee_id = $1 
           ORDER BY date DESC 
           LIMIT 1`,
          [employee_id]
        );

        if (latestAttendance.rows.length > 0) {
          const currentOutstanding = parseFloat(latestAttendance.rows[0].outstanding_advance) || 0;
          const newOutstanding = Math.max(0, currentOutstanding - advance_deducted);
          const attendanceDate = latestAttendance.rows[0].date;

          // Update the latest attendance record with new outstanding
          await db.query(
            `UPDATE attendance 
             SET outstanding_advance = $1, updated_at = CURRENT_TIMESTAMP
             WHERE id = $2`,
            [newOutstanding, latestAttendance.rows[0].id]
          );

          // Also update all future attendance records for this employee
          await db.query(
            `UPDATE attendance 
             SET outstanding_advance = GREATEST(0, outstanding_advance - $1), 
                 updated_at = CURRENT_TIMESTAMP
             WHERE employee_id = $2 AND date > $3`,
            [advance_deducted, employee_id, attendanceDate]
          );
        }
      } catch (updateErr) {
        console.error('Error updating attendance outstanding advance:', updateErr);
        // Don't fail the salary expense save if attendance update fails
      }
    }

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error saving salary expense:', err);
    res.status(500).json({ 
      message: 'Error saving salary expense',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Bulk create or update salary expenses
router.post('/bulk', async (req, res) => {
  try {
    const { salary_records } = req.body;

    const results = [];
    for (const record of salary_records) {
      const {
        employee_id,
        employee_name,
        sector,
        week_start_date,
        week_end_date,
        outstanding_advance,
        days_present,
        estimated_salary,
        advance_deducted,
        salary_issued,
        salary_issued_date,
        selected_dates,
      } = record;

      // Always create new record (supports multiple entries per month)
      const { rows } = await db.query(
        `INSERT INTO salary_expenses (
          employee_id, employee_name, sector, week_start_date, week_end_date,
          outstanding_advance, days_present, estimated_salary,
          advance_deducted, salary_issued, salary_issued_date, selected_dates
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING *`,
        [
          employee_id,
          employee_name,
          sector,
          week_start_date,
          week_end_date,
          outstanding_advance || 0,
          days_present || 0,
          estimated_salary || 0,
          advance_deducted || 0,
          salary_issued || 0,
          salary_issued_date || null,
          selected_dates ? JSON.stringify(selected_dates) : null,
        ]
      );
      results.push(rows[0]);

      // If advance was deducted, update attendance outstanding advance
      if (advance_deducted && advance_deducted > 0) {
        try {
          const latestAttendance = await db.query(
            `SELECT id, outstanding_advance, date 
             FROM attendance 
             WHERE employee_id = $1 
             ORDER BY date DESC 
             LIMIT 1`,
            [employee_id]
          );

          if (latestAttendance.rows.length > 0) {
            const currentOutstanding = parseFloat(latestAttendance.rows[0].outstanding_advance) || 0;
            const newOutstanding = Math.max(0, currentOutstanding - advance_deducted);
            const attendanceDate = latestAttendance.rows[0].date;

            await db.query(
              `UPDATE attendance 
               SET outstanding_advance = $1, updated_at = CURRENT_TIMESTAMP
               WHERE id = $2`,
              [newOutstanding, latestAttendance.rows[0].id]
            );

            await db.query(
              `UPDATE attendance 
               SET outstanding_advance = GREATEST(0, outstanding_advance - $1), 
                   updated_at = CURRENT_TIMESTAMP
               WHERE employee_id = $2 AND date > $3`,
              [advance_deducted, employee_id, attendanceDate]
            );
          }
        } catch (updateErr) {
          console.error('Error updating attendance outstanding advance:', updateErr);
        }
      }
    }

    res.json(results);
  } catch (err) {
    console.error('Error bulk saving salary expenses:', err);
    res.status(500).json({ message: 'Error bulk saving salary expenses' });
  }
});

// Delete salary expense
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await db.query(
      'DELETE FROM salary_expenses WHERE id = $1 RETURNING *',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Salary expense not found' });
    }
    
    res.status(200).json({ message: 'Salary expense deleted successfully' });
  } catch (err) {
    console.error('Error deleting salary expense:', err);
    res.status(500).json({ 
      message: 'Error deleting salary expense',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

