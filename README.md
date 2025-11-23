# Central360

This is the dedicated project root for Central360, separate from any employee-management-system scaffolding.

## Structure

```
central360/
├── README.md
├── assets/
│   └── brand/
│       └── c360-logo.png    # (legacy) general brand asset
└── docs/
    └── PROJECT_STRUCTURE.md # copied/derived from the planning document

frontend/                     # Flutter app
├── pubspec.yaml
└── lib/
    ├── main.dart
    └── screens/
        └── login_screen.dart
└── assets/
    └── brand/
        └── c360-logo.png     # Flutter loads this path

backend/                      # Node.js + Express + PostgreSQL
├── package.json
├── env.example
└── src/
    ├── index.js
    ├── server.js
    ├── db.js
    └── routes/
        └── auth.routes.js
```

## Branding

- Logo expected at: `central360/assets/brand/c360-logo.png`
- Preferred usage: splash, login, app icon, installer assets
- Colors: gold/yellow sun accent with white “360” on dark background

## Next

1. Copy your logo to `central360/frontend/assets/brand/c360-logo.png` (required by Flutter).
2. Backend
   - Create `.env` (copy from `backend/env.example`) and set `DATABASE_URL`, `JWT_SECRET`.
   - From `central360/backend/`, run:
     - `npm install`
     - `npm run dev`
3. Flutter
   - From `central360/frontend/`, run:
     - `flutter pub get`
     - `flutter run -d windows` (or your target)

Login screen fields:
- Company name
- User name
- Password


