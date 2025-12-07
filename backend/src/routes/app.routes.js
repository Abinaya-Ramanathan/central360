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
      version: '1.0.17',  // Update this when releasing new version
      buildNumber: '18',  // Update this when releasing new version
      platforms: {
        windows: {
          downloadUrl: 'https://github.com/Abinaya-Ramanathan/central360/releases/download/v1.0.17/company360-setup.exe',
          isRequired: false,
        },
        android: {
          downloadUrl: 'https://github.com/Abinaya-Ramanathan/central360/releases/download/v1.0.17/company360-v1.0.17.apk',
          isRequired: false,
        }
      },
      releaseNotes: 'Fixed update check bug - app was repeatedly asking for updates even when on latest version. Improved version comparison logic, added cooldown period, and enhanced dismissed version handling. Backend version 0.1.4',
      isRequired: false,  // Set to true for critical security updates
      releaseDate: '2025-01-28T00:00:00Z',
    };
    
    res.json(versionInfo);
  } catch (error) {
    console.error('Error getting app version:', error);
    res.status(500).json({ message: 'Error getting version information' });
  }
});

export default router;

