import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get mahal bookings - select event_date as text so we always get YYYY-MM-DD (no timezone conversion)
const MAHAL_SELECT = `booking_id, sector_code, mahal_detail, event_date::text AS event_date, event_timing,
  event_name, client_name, client_phone1, client_phone2, client_address, food_service,
  advance_received, quoted_amount, amount_received, final_settlement_amount, order_status, details, created_at, updated_at`;

router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;
    let query = `SELECT ${MAHAL_SELECT} FROM mahal_bookings WHERE 1=1`;
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY event_date DESC, created_at DESC';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching mahal bookings:', err);
    res.status(500).json({ message: 'Error fetching mahal bookings' });
  }
});

// Normalize event_date to YYYY-MM-DD string only (calendar date, no timezone).
// Use this so storage and API never shift the day (India / local business).
function normalizeEventDate(eventDate) {
  if (eventDate == null) return null;
  if (typeof eventDate === 'string') {
    const part = eventDate.trim().split('T')[0].split(' ')[0].replace(/\//g, '-');
    return part.length >= 10 ? part.substring(0, 10) : part;
  }
  if (eventDate instanceof Date) {
    const y = eventDate.getUTCFullYear();
    const m = String(eventDate.getUTCMonth() + 1).padStart(2, '0');
    const d = String(eventDate.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  return null;
}

// Create or update mahal booking
router.post('/', async (req, res) => {
  try {
    const {
      booking_id,
      old_booking_id,
      sector_code,
      mahal_detail,
      event_date: rawEventDate,
      event_timing,
      event_name,
      client_name,
      client_phone1,
      client_phone2,
      client_address,
      food_service,
      advance_received,
      quoted_amount,
      amount_received,
      final_settlement_amount,
      order_status,
      details,
    } = req.body;

    const event_date = normalizeEventDate(rawEventDate);

    if (!sector_code || !mahal_detail || !event_date || !client_name) {
      return res.status(400).json({ 
        message: 'Sector code, mahal detail, event date, and client name are required' 
      });
    }

    // Generate booking_id if not provided: client_name + event_date
    let generatedBookingId = booking_id;
    if (!generatedBookingId) {
      const cleanClientName = client_name.replace(/[^a-zA-Z0-9]/g, '');
      generatedBookingId = `${cleanClientName}_${event_date}`;
    }

    const newId = generatedBookingId;
    const oldId = old_booking_id;

    // When event date is updated, booking_id must change. FK requires new id to exist in mahal_bookings first.
    // So: insert new row -> update child tables to new id -> delete old row.
    if (oldId && oldId !== newId) {
      const client = await db.pool.connect();
      try {
        await client.query('BEGIN');
        const insertResult = await client.query(
          `INSERT INTO mahal_bookings (
            booking_id, sector_code, mahal_detail, event_date, event_timing,
            event_name, client_name, client_phone1, client_phone2, client_address,
            food_service, advance_received, quoted_amount, amount_received, final_settlement_amount, order_status, details
          ) VALUES ($1, $2, $3, $4::date, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
          RETURNING *`,
          [
            newId, sector_code, mahal_detail, event_date, event_timing || null, event_name || null,
            client_name, client_phone1 || null, client_phone2 || null, client_address || null,
            food_service || null, advance_received || null, quoted_amount || null, amount_received || null,
            final_settlement_amount || null, order_status || 'open', details || null,
          ]
        );
        const row = insertResult.rows[0];
        if (!row) {
          await client.query('ROLLBACK');
          return res.status(500).json({ message: 'Failed to insert updated booking' });
        }
        await client.query('UPDATE catering_details SET booking_id = $1 WHERE booking_id = $2', [newId, oldId]);
        await client.query('UPDATE expense_details SET booking_id = $1 WHERE booking_id = $2', [newId, oldId]);
        await client.query('UPDATE billing_details SET booking_id = $1 WHERE booking_id = $2', [newId, oldId]).catch(() => {});
        await client.query('DELETE FROM mahal_bookings WHERE booking_id = $1', [oldId]);
        await client.query('COMMIT');
        const eventDateStr = normalizeEventDate(row.event_date);
        const responseRow = { ...row, event_date: eventDateStr ?? row.event_date };
        return res.status(201).json(responseRow);
      } catch (err) {
        await client.query('ROLLBACK').catch(() => {});
        throw err;
      } finally {
        client.release();
      }
    }

    // Insert or update by conflict (same booking_id)
    const result = await db.query(
      `INSERT INTO mahal_bookings (
        booking_id, sector_code, mahal_detail, event_date, event_timing,
        event_name, client_name, client_phone1, client_phone2, client_address, 
        food_service, advance_received, quoted_amount, amount_received, final_settlement_amount, order_status, details
      ) VALUES ($1, $2, $3, $4::date, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
      ON CONFLICT (booking_id) DO UPDATE SET
        sector_code = EXCLUDED.sector_code,
        mahal_detail = EXCLUDED.mahal_detail,
        event_date = EXCLUDED.event_date,
        event_timing = EXCLUDED.event_timing,
        event_name = EXCLUDED.event_name,
        client_name = EXCLUDED.client_name,
        client_phone1 = EXCLUDED.client_phone1,
        client_phone2 = EXCLUDED.client_phone2,
        client_address = EXCLUDED.client_address,
        food_service = EXCLUDED.food_service,
        advance_received = EXCLUDED.advance_received,
        quoted_amount = EXCLUDED.quoted_amount,
        amount_received = EXCLUDED.amount_received,
        final_settlement_amount = EXCLUDED.final_settlement_amount,
        order_status = EXCLUDED.order_status,
        details = EXCLUDED.details,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *`,
      [
        newId,
        sector_code,
        mahal_detail,
        event_date,
        event_timing || null,
        event_name || null,
        client_name,
        client_phone1 || null,
        client_phone2 || null,
        client_address || null,
        food_service || null,
        advance_received || null,
        quoted_amount || null,
        amount_received || null,
        final_settlement_amount || null,
        order_status || 'open',
        details || null,
      ]
    );
    const row = result.rows[0];
    const eventDateStr = normalizeEventDate(row?.event_date);
    const responseRow = row ? { ...row, event_date: eventDateStr ?? row.event_date } : row;

    res.status(201).json(responseRow);
  } catch (err) {
    console.error('Error saving mahal booking:', err);
    res.status(500).json({
      message: 'Error saving event details',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete mahal booking
router.delete('/:booking_id', async (req, res) => {
  try {
    const { booking_id } = req.params;

    const result = await db.query(
      'DELETE FROM mahal_bookings WHERE booking_id = $1 RETURNING *',
      [booking_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Event details not found' });
    }

    res.status(200).json({ message: 'Event details deleted successfully' });
  } catch (err) {
    console.error('Error deleting event details:', err);
    res.status(500).json({
      message: 'Error deleting event details',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

