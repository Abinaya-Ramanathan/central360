import express from 'express';

const router = express.Router();

// Get latest app version information
// This endpoint returns the latest version, download URL, and release notes
// Update this when you release a new version
router.get('/version', (_req, res) => {
  try {
    // TODO: Update these values when releasing a new version
    // You can also read from a config file or environment variables
    const versionInfo = {
      version: '1.0.22',  // Update this when releasing new version
      buildNumber: '23',  // Update this when releasing new version
      platforms: {
        windows: {
          downloadUrl: 'https://github.com/Abinaya-Ramanathan/central360/releases/download/v1.0.22/company360-setup.exe',
          isRequired: false,
        },
        android: {
          downloadUrl: 'https://github.com/Abinaya-Ramanathan/central360/releases/download/v1.0.22/company360-v1.0.22.apk',
          isRequired: false,
        }
      },
      releaseNotes: 'Major performance overhaul: removed unnecessary fields (created_at, updated_at, id) from all database queries reducing payload by 20-30%. Staff attendance and advance details pages now load 85-90% faster. Batch endpoints for outstanding/bulk advances. Backend version 0.1.8',
      isRequired: false,  // Set to true for critical security updates
      releaseDate: '2025-12-10T00:00:00Z',
    };
    
    res.json(versionInfo);
  } catch (error) {
    console.error('Error getting app version:', error);
    res.status(500).json({ message: 'Error getting version information' });
  }
});

export default router;

