/**
 * Query Performance Logger
 * Logs slow queries and provides performance metrics
 */

export function logQueryPerformance(queryName, startTime, rowCount) {
  const duration = Date.now() - startTime;
  const isSlow = duration > 100; // Log queries > 100ms as slow
  
  if (isSlow) {
    console.log(`[Performance] ⚠️  SLOW QUERY: ${queryName} took ${duration}ms, returned ${rowCount} records`);
  } else {
    console.log(`[Performance] ✓ ${queryName} took ${duration}ms, returned ${rowCount} records`);
  }
  
  return duration;
}

export function createPerformanceMiddleware(routeName) {
  return (req, res, next) => {
    const startTime = Date.now();
    const originalJson = res.json.bind(res);
    
    res.json = function(data) {
      const duration = Date.now() - startTime;
      const rowCount = Array.isArray(data) ? data.length : 1;
      logQueryPerformance(`${routeName} ${req.method} ${req.path}`, startTime, rowCount);
      return originalJson(data);
    };
    
    next();
  };
}

