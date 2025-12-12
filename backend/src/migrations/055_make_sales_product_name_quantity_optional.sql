-- Make sales_details.product_name and quantity fields optional
ALTER TABLE sales_details ALTER COLUMN product_name DROP NOT NULL;
ALTER TABLE sales_details ALTER COLUMN quantity DROP NOT NULL;
