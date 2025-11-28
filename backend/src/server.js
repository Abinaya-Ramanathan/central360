import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import authRouter from './routes/auth.routes.js';
import employeesRouter from './routes/employees.routes.js';
import sectorsRouter from './routes/sectors.routes.js';
import attendanceRouter from './routes/attendance.routes.js';
import salaryExpensesRouter from './routes/salary_expenses.routes.js';
import contractEmployeesRouter from './routes/contract_employees.routes.js';
import dailyProductionRouter from './routes/daily_production.routes.js';
import productsRouter from './routes/products.routes.js';
import dailyExpensesRouter from './routes/daily_expenses.routes.js';
import maintenanceIssuesRouter from './routes/maintenance_issues.routes.js';
import mahalBookingsRouter from './routes/mahal_bookings.routes.js';
import billingDetailsRouter from './routes/billing_details.routes.js';
import cateringDetailsRouter from './routes/catering_details.routes.js';
import expenseDetailsRouter from './routes/expense_details.routes.js';
import creditDetailsRouter from './routes/credit_details.routes.js';
import salesDetailsRouter from './routes/sales_details.routes.js';
import companyPurchaseDetailsRouter from './routes/company_purchase_details.routes.js';
import vehicleLicensesRouter from './routes/vehicle_licenses.routes.js';
import driverLicensesRouter from './routes/driver_licenses.routes.js';
import engineOilServicesRouter from './routes/engine_oil_services.routes.js';
import emailRouter from './routes/email.routes.js';
import stockItemsRouter from './routes/stock_items.routes.js';
import dailyStockRouter from './routes/daily_stock.routes.js';
import overallStockRouter from './routes/overall_stock.routes.js';
import stockStatementRouter from './routes/stock_statement.routes.js';
import appRouter from './routes/app.routes.js';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json());
// Serve uploaded images
app.use('/uploads', express.static(join(__dirname, '../uploads')));

// Health check endpoints (for Railway and monitoring)
app.get('/', (_req, res) => {
  res.json({ status: 'ok', service: 'Company360 API' });
});

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', service: 'Company360 API' });
});

app.use('/api/v1/auth', authRouter);
app.use('/api/v1/employees', employeesRouter);
app.use('/api/v1/sectors', sectorsRouter);
app.use('/api/v1/attendance', attendanceRouter);
app.use('/api/v1/salary-expenses', salaryExpensesRouter);
app.use('/api/v1/contract-employees', contractEmployeesRouter);
app.use('/api/v1/daily-production', dailyProductionRouter);
app.use('/api/v1/products', productsRouter);
app.use('/api/v1/daily-expenses', dailyExpensesRouter);
app.use('/api/v1/maintenance-issues', maintenanceIssuesRouter);
app.use('/api/v1/mahal-bookings', mahalBookingsRouter);
app.use('/api/v1/billing-details', billingDetailsRouter);
app.use('/api/v1/catering-details', cateringDetailsRouter);
app.use('/api/v1/expense-details', expenseDetailsRouter);
app.use('/api/v1/credit-details', creditDetailsRouter);
app.use('/api/v1/sales-details', salesDetailsRouter);
app.use('/api/v1/company-purchase-details', companyPurchaseDetailsRouter);
app.use('/api/v1/vehicle-licenses', vehicleLicensesRouter);
app.use('/api/v1/driver-licenses', driverLicensesRouter);
app.use('/api/v1/engine-oil-services', engineOilServicesRouter);
app.use('/api/v1/email', emailRouter);
app.use('/api/v1/stock-items', stockItemsRouter);
app.use('/api/v1/daily-stock', dailyStockRouter);
app.use('/api/v1/overall-stock', overallStockRouter);
app.use('/api/v1/stock-statement', stockStatementRouter);
app.use('/api/v1/app', appRouter);

export default app;


