-- Quick Database Check Queries
-- Run these in Railway Dashboard → PostgreSQL → Query tab

-- 1. Check if employees exist
SELECT COUNT(*) as total_employees FROM employees;

-- 2. View all employees
SELECT 
  id,
  name,
  contact,
  sector,
  role,
  daily_salary,
  weekly_salary,
  monthly_salary
FROM employees
ORDER BY name;

-- 3. Check sectors
SELECT code, name FROM sectors ORDER BY code;

-- 4. Check employees with their sector names
SELECT 
  e.id,
  e.name,
  e.sector as sector_code,
  s.name as sector_name,
  e.contact
FROM employees e
LEFT JOIN sectors s ON e.sector = s.code
ORDER BY e.name;

-- 5. Find employees with invalid sectors (not in sectors table)
SELECT 
  e.id,
  e.name,
  e.sector,
  'INVALID SECTOR' as status
FROM employees e
LEFT JOIN sectors s ON e.sector = s.code
WHERE s.code IS NULL;

-- 6. Count employees by sector
SELECT 
  COALESCE(s.name, e.sector) as sector_name,
  COUNT(*) as employee_count
FROM employees e
LEFT JOIN sectors s ON e.sector = s.code
GROUP BY COALESCE(s.name, e.sector), e.sector
ORDER BY employee_count DESC;

-- 7. Fix sector case sensitivity (if needed)
-- Uncomment to run:
-- UPDATE employees SET sector = UPPER(TRIM(sector));

-- 8. View latest employees
SELECT * FROM employees 
ORDER BY created_at DESC 
LIMIT 10;

