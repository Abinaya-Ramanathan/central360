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
      version: '1.0.1',  // Update this
  buildNumber: '2',  // Update this
  downloadUrl: 'https://github.com/Abinaya-Ramanathan/central360/releases/download/v1.0.1/Company360-Setup.exe',
  releaseNotes: 'Auto update fix',
  isRequired: false,  // Set to true for critical updates
  releaseDate: '2025-11-25T00:00:00Z',
    };
    
    res.json(versionInfo);
  } catch (error) {
    console.error('Error getting app version:', error);
    res.status(500).json({ message: 'Error getting version information' });
  }
});

export default router;

