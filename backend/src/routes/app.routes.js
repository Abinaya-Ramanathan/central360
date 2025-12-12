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
      version: '1.0.23',  // Update this when releasing new version
      buildNumber: '24',  // Update this when releasing new version
      platforms: {
        windows: {
          downloadUrl: 'https://github.com/Abinaya-Ramanathan/central360/releases/download/v1.0.23/company360-setup.exe',
          isRequired: false,
        },
        android: {
          downloadUrl: 'https://github.com/Abinaya-Ramanathan/central360/releases/download/v1.0.23/company360-v1.0.23.apk',
          isRequired: false,
        }
      },
      releaseNotes: 'Added final settlement amount field to event details with inline editing. Added date range filters with clear options for Sales Credit, Purchase Credit, and Event Details. Added total row in Event Details showing settlement amount sum and booking count. Customized SSMMC sector to show only Maintenance, Sales Purchase Credit, and Mahal Booking buttons. Backend version 0.1.9',
      isRequired: false,  // Set to true for critical security updates
      releaseDate: '2025-01-15T00:00:00Z',
    };
    
    res.json(versionInfo);
  } catch (error) {
    console.error('Error getting app version:', error);
    res.status(500).json({ message: 'Error getting version information' });
  }
});

export default router;

