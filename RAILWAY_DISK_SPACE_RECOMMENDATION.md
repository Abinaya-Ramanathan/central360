# Railway Disk Space Recommendation for Central360

## Application Analysis

### Database Storage (PostgreSQL)
- **26 Database Tables** including:
  - Employee management (employees, attendance, salary_expenses)
  - Daily operations (daily_production, daily_stock, daily_expenses)
  - Booking management (mahal_bookings, catering_details, expense_details)
  - Purchase & credit tracking (company_purchase_details, credit_details, sales_details)
  - Maintenance (maintenance_issues, maintenance_issue_photos)
  - Vehicle management (rent_vehicles, rent_vehicle_attendance)
  - Ingredients (ingredient_menus, ingredient_items)

- **Data Types**: Mostly text, dates, decimals, integers
- **Growth Pattern**: Daily transactional data that accumulates over time

### File Storage (Filesystem)
- **Image Uploads**:
  - Maintenance issue photos: Up to **10MB per image**, up to **10 photos per issue**
  - Company purchase photos: Up to **10MB per image**, up to **10 photos per purchase**
  - Storage location: `/uploads/maintenance/` and `/uploads/purchases/`

## Storage Calculation

### 1. Database Storage (Year 1)
- **Initial Setup**: ~50-100 MB
  - Tables, indexes, constraints
- **Daily Data Growth**: ~5-15 MB/day
  - Attendance records: ~2 MB/day
  - Daily production/stock: ~3 MB/day
  - Expenses/transactions: ~5 MB/day
  - Other operations: ~2 MB/day
- **Monthly Growth**: ~150-450 MB/month
- **Year 1 Total**: ~2-5 GB

### 2. Image Storage (Year 1)
- **Average Image Size**: 2-3 MB (compressed)
- **Estimated Uploads**:
  - Maintenance issues: ~5-10 issues/month × 3 photos = 15-30 photos/month
  - Company purchases: ~10-20 purchases/month × 2 photos = 20-40 photos/month
  - Total: ~35-70 photos/month
- **Monthly Storage**: ~70-210 MB/month
- **Year 1 Total**: ~1-2.5 GB

### 3. System Overhead
- PostgreSQL WAL (Write-Ahead Logging): ~500 MB - 1 GB
- Temporary files and indexes: ~500 MB - 1 GB
- OS and application files: ~500 MB

### 4. Growth Projection
- **Year 1**: ~4-8 GB
- **Year 2**: ~8-16 GB (with data retention)
- **Year 3**: ~12-24 GB (with data retention)

## Railway Disk Space Recommendations

### 🟢 **Minimum Recommended: 20 GB**
**Best for:**
- Starting out / testing
- Low to moderate usage
- Can upgrade later if needed

**Considerations:**
- Allows ~1-2 years of growth at current pace
- Sufficient for moderate image uploads
- Can handle database growth comfortably

### 🟡 **Recommended: 50 GB** ⭐ **RECOMMENDED**
**Best for:**
- Production use
- Multiple sectors/branches
- Regular daily operations
- Moderate to high image uploads

**Benefits:**
- Comfortable buffer for 3-4 years of growth
- Handles unexpected spikes in usage
- Reduces risk of running out of space
- Better performance (more free space = better DB performance)
- Room for database maintenance operations

### 🔵 **Optimal: 100 GB**
**Best for:**
- High-volume operations
- Multiple heavy users
- Aggressive growth plans
- Long-term data retention (5+ years)
- Multiple image uploads daily

**Benefits:**
- Very comfortable for 5+ years
- No worries about storage limits
- Excellent performance buffer
- Can store high-resolution images without concern

## Performance Considerations

### Why More Space = Better Performance

1. **Database Performance**
   - PostgreSQL performs better with free space (15-20% free recommended)
   - Indexes and query plans work better with adequate space
   - VACUUM operations need space to run efficiently

2. **Disk I/O**
   - Less disk fragmentation with more free space
   - Faster write operations
   - Better caching behavior

3. **Avoid Issues**
   - Running out of space can cause database corruption
   - No space for temporary files = query failures
   - Image uploads will fail if disk is full

## Cost Considerations (Railway Pricing)

- **20 GB**: Included in most plans
- **50 GB**: ~$5-10/month additional
- **100 GB**: ~$10-20/month additional

*Note: Railway pricing may vary. Check current pricing on railway.app*

## Migration Strategy

### Start with 20 GB, Monitor and Upgrade
1. **Month 1-3**: Monitor actual usage
2. **Set Alerts**: Alert at 70% capacity
3. **Upgrade Path**: Easy to upgrade disk size in Railway
4. **Review Monthly**: Check growth rate and adjust

### Monitoring Commands
```sql
-- Check database size
SELECT pg_size_pretty(pg_database_size('your_database_name'));

-- Check table sizes
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## My Recommendation

### 🎯 **Start with 50 GB for Production**

**Reasoning:**
1. **Safe Buffer**: 50 GB provides comfortable room for 3-4 years of growth
2. **Cost-Effective**: Reasonable monthly cost (~$5-10/month)
3. **Performance**: Adequate free space for optimal database performance
4. **Image Storage**: Handles moderate image uploads without concern
5. **Future-Proof**: Allows business growth without immediate upgrades
6. **Peace of Mind**: Reduces risk of running out of space unexpectedly

### Minimum Safe Starting Point: **20 GB**
- Only if budget is very tight
- Must monitor closely
- Plan to upgrade within 6-12 months

### If High Volume Expected: **100 GB**
- Multiple sectors with heavy usage
- Many daily transactions
- Regular image uploads
- Long-term data retention needs

## Additional Tips

1. **Enable Database Maintenance**
   - Regular VACUUM operations
   - Monitor table bloat
   - Archive old data if needed

2. **Optimize Image Storage**
   - Consider image compression
   - Set reasonable limits (already at 10MB per image)
   - Consider cloud storage (S3) for images in future

3. **Data Retention Policy**
   - Archive old data (>2 years) to reduce storage
   - Keep recent data hot for performance
   - Use database partitioning for large tables

4. **Monitor Growth**
   - Set up Railway alerts at 70% capacity
   - Review storage usage monthly
   - Plan upgrades proactively

---

**Final Recommendation: Start with 50 GB disk space for optimal performance and peace of mind.**




