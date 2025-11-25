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
      version: process.env.APP_VERSION || '1.0.0',
      buildNumber: process.env.APP_BUILD_NUMBER || '1',
      downloadUrl: process.env.APP_DOWNLOAD_URL || '', // GitHub release URL or direct download link
      releaseNotes: process.env.APP_RELEASE_NOTES || 'Bug fixes and improvements',
      isRequired: process.env.APP_UPDATE_REQUIRED === 'true' || false,
      releaseDate: process.env.APP_RELEASE_DATE || new Date().toISOString(),
    };
    
    res.json(versionInfo);
  } catch (error) {
    console.error('Error getting app version:', error);
    res.status(500).json({ message: 'Error getting version information' });
  }
});

export default router;

