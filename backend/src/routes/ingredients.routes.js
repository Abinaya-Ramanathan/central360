import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get all ingredient menus with their items
router.get('/', async (req, res) => {
  try {
    const { search } = req.query;
    
    let query = `
      SELECT 
        m.id,
        m.menu,
        m.members_count,
        m.created_at,
        m.updated_at,
        COALESCE(
          json_agg(
            json_build_object(
              'id', i.id,
              'ingredient_name', i.ingredient_name,
              'quantity', i.quantity,
              'unit', i.unit
            ) ORDER BY i.id
          ) FILTER (WHERE i.id IS NOT NULL),
          '[]'::json
        ) as ingredients
      FROM ingredient_menus m
      LEFT JOIN ingredient_items i ON m.id = i.menu_id
    `;
    
    const params = [];
    if (search) {
      query += ` WHERE m.menu ILIKE $1`;
      params.push(`%${search}%`);
    }
    
    query += ` GROUP BY m.id, m.menu, m.members_count, m.created_at, m.updated_at ORDER BY m.created_at DESC`;
    
    const result = await db.query(query, params);
    
    const menus = result.rows.map(row => ({
      id: row.id,
      menu: row.menu,
      members_count: row.members_count,
      ingredients: row.ingredients,
      created_at: row.created_at,
      updated_at: row.updated_at,
    }));
    
    res.json(menus);
  } catch (error) {
    console.error('Error fetching ingredients:', error);
    res.status(500).json({ message: 'Error fetching ingredients', error: error.message });
  }
});

// Get single ingredient menu by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await db.query(
      `SELECT 
        m.id,
        m.menu,
        m.members_count,
        m.created_at,
        m.updated_at,
        COALESCE(
          json_agg(
            json_build_object(
              'id', i.id,
              'ingredient_name', i.ingredient_name,
              'quantity', i.quantity,
              'unit', i.unit
            ) ORDER BY i.id
          ) FILTER (WHERE i.id IS NOT NULL),
          '[]'::json
        ) as ingredients
      FROM ingredient_menus m
      LEFT JOIN ingredient_items i ON m.id = i.menu_id
      WHERE m.id = $1
      GROUP BY m.id, m.menu, m.members_count, m.created_at, m.updated_at`,
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Ingredient menu not found' });
    }
    
    const menu = {
      id: result.rows[0].id,
      menu: result.rows[0].menu,
      members_count: result.rows[0].members_count,
      ingredients: result.rows[0].ingredients,
      created_at: result.rows[0].created_at,
      updated_at: result.rows[0].updated_at,
    };
    
    res.json(menu);
  } catch (error) {
    console.error('Error fetching ingredient menu:', error);
    res.status(500).json({ message: 'Error fetching ingredient menu', error: error.message });
  }
});

// Create new ingredient menu with items
router.post('/', async (req, res) => {
  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');
    
    const { menu, members_count, ingredients } = req.body;
    
    if (!menu || !members_count || !ingredients || !Array.isArray(ingredients) || ingredients.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ message: 'Menu, members_count, and ingredients array are required' });
    }
    
    // Insert menu
    const menuResult = await client.query(
      'INSERT INTO ingredient_menus (menu, members_count) VALUES ($1, $2) RETURNING id',
      [menu, members_count]
    );
    
    const menuId = menuResult.rows[0].id;
    
    // Insert ingredient items
    for (const ingredient of ingredients) {
      if (!ingredient.ingredient_name || !ingredient.quantity || !ingredient.unit) {
        await client.query('ROLLBACK');
        return res.status(400).json({ message: 'Each ingredient must have ingredient_name, quantity, and unit' });
      }
      
      await client.query(
        'INSERT INTO ingredient_items (menu_id, ingredient_name, quantity, unit) VALUES ($1, $2, $3, $4)',
        [menuId, ingredient.ingredient_name, ingredient.quantity, ingredient.unit]
      );
    }
    
    await client.query('COMMIT');
    
    // Fetch and return the created menu with items
    const result = await db.query(
      `SELECT 
        m.id,
        m.menu,
        m.members_count,
        m.created_at,
        m.updated_at,
        COALESCE(
          json_agg(
            json_build_object(
              'id', i.id,
              'ingredient_name', i.ingredient_name,
              'quantity', i.quantity,
              'unit', i.unit
            ) ORDER BY i.id
          ) FILTER (WHERE i.id IS NOT NULL),
          '[]'::json
        ) as ingredients
      FROM ingredient_menus m
      LEFT JOIN ingredient_items i ON m.id = i.menu_id
      WHERE m.id = $1
      GROUP BY m.id, m.menu, m.members_count, m.created_at, m.updated_at`,
      [menuId]
    );
    
    res.status(201).json({
      id: result.rows[0].id,
      menu: result.rows[0].menu,
      members_count: result.rows[0].members_count,
      ingredients: result.rows[0].ingredients,
      created_at: result.rows[0].created_at,
      updated_at: result.rows[0].updated_at,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error creating ingredient menu:', error);
    res.status(500).json({ message: 'Error creating ingredient menu', error: error.message });
  } finally {
    client.release();
  }
});

// Update ingredient menu and items
router.put('/:id', async (req, res) => {
  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');
    
    const { id } = req.params;
    const { menu, members_count, ingredients } = req.body;
    
    if (!menu || !members_count || !ingredients || !Array.isArray(ingredients)) {
      await client.query('ROLLBACK');
      return res.status(400).json({ message: 'Menu, members_count, and ingredients array are required' });
    }
    
    // Update menu
    await client.query(
      'UPDATE ingredient_menus SET menu = $1, members_count = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3',
      [menu, members_count, id]
    );
    
    // Delete existing items
    await client.query('DELETE FROM ingredient_items WHERE menu_id = $1', [id]);
    
    // Insert new items
    for (const ingredient of ingredients) {
      if (!ingredient.ingredient_name || !ingredient.quantity || !ingredient.unit) {
        await client.query('ROLLBACK');
        return res.status(400).json({ message: 'Each ingredient must have ingredient_name, quantity, and unit' });
      }
      
      await client.query(
        'INSERT INTO ingredient_items (menu_id, ingredient_name, quantity, unit) VALUES ($1, $2, $3, $4)',
        [id, ingredient.ingredient_name, ingredient.quantity, ingredient.unit]
      );
    }
    
    await client.query('COMMIT');
    
    // Fetch and return the updated menu with items
    const result = await db.query(
      `SELECT 
        m.id,
        m.menu,
        m.members_count,
        m.created_at,
        m.updated_at,
        COALESCE(
          json_agg(
            json_build_object(
              'id', i.id,
              'ingredient_name', i.ingredient_name,
              'quantity', i.quantity,
              'unit', i.unit
            ) ORDER BY i.id
          ) FILTER (WHERE i.id IS NOT NULL),
          '[]'::json
        ) as ingredients
      FROM ingredient_menus m
      LEFT JOIN ingredient_items i ON m.id = i.menu_id
      WHERE m.id = $1
      GROUP BY m.id, m.menu, m.members_count, m.created_at, m.updated_at`,
      [id]
    );
    
    res.json({
      id: result.rows[0].id,
      menu: result.rows[0].menu,
      members_count: result.rows[0].members_count,
      ingredients: result.rows[0].ingredients,
      created_at: result.rows[0].created_at,
      updated_at: result.rows[0].updated_at,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error updating ingredient menu:', error);
    res.status(500).json({ message: 'Error updating ingredient menu', error: error.message });
  } finally {
    client.release();
  }
});

// Delete ingredient menu (cascades to items)
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await db.query('DELETE FROM ingredient_menus WHERE id = $1 RETURNING id', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Ingredient menu not found' });
    }
    
    res.status(200).json({ message: 'Ingredient menu deleted successfully' });
  } catch (error) {
    console.error('Error deleting ingredient menu:', error);
    res.status(500).json({ message: 'Error deleting ingredient menu', error: error.message });
  }
});

export default router;

