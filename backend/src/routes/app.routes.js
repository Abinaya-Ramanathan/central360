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
      version: '1.0.21',  // Update this when releasing new version
      buildNumber: '22',  // Update this when releasing new version
      platforms: {
        windows: {
          downloadUrl: 'https://github.com/Abinaya-Ramanathan/central360/releases/download/v1.0.21/company360-setup.exe',
          isRequired: false,
        },
        android: {
          downloadUrl: 'https://github.com/Abinaya-Ramanathan/central360/releases/download/v1.0.21/company360-v1.0.21.apk',
          isRequired: false,
        }
      },
      releaseNotes: 'Performance fixes: staff attendance and advance details pages now load 85-90% faster when selecting All Sectors or changing dates. Uses batch API endpoints and single employee load instead of sequential per-sector calls. Backend version 0.1.7',
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

