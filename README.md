# Company360

Comprehensive Business Management Application for managing employees, expenses, bookings, credit details, vehicle licenses, and more.

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ and npm
- Flutter 3.0+
- PostgreSQL database
- Git

### Installation

#### Backend
```bash
cd backend
npm install
cp .env.example .env  # Edit .env with your database credentials
npm start
```

#### Frontend
```bash
cd frontend
flutter pub get
flutter run -d windows
```

## 📦 Download Windows Installer

**Latest Release:**
[Download Company360 Installer](https://github.com/YOUR_USERNAME/company360/releases/latest/download/company360-setup.exe)

**System Requirements:**
- Windows 10 or later
- 64-bit system
- Internet connection

## 🏗️ Project Structure

```
company360/
├── backend/          # Node.js + Express + PostgreSQL
│   ├── src/
│   │   ├── routes/   # API routes
│   │   ├── migrations/ # Database migrations
│   │   └── index.js  # Server entry point
│   └── package.json
├── frontend/         # Flutter application
│   ├── lib/
│   │   ├── screens/  # UI screens
│   │   ├── services/ # API services
│   │   └── models/   # Data models
│   └── pubspec.yaml
└── assets/           # Brand assets
    └── brand/
        └── c360-icon.ico
```

## 🔧 Development

### Backend Development
```bash
cd backend
npm run dev  # Development mode with auto-reload
```

### Frontend Development
```bash
cd frontend
flutter run -d windows  # Run on Windows
```

## 🌐 Deployment

### Backend (Railway)
1. Connect GitHub repository to Railway
2. Set root directory to `backend/`
3. Add PostgreSQL database
4. Set environment variables
5. Deploy automatically

### Frontend (Build Installer)
```bash
# Build with production API URL
cd frontend
flutter build windows --release --dart-define=API_BASE_URL=https://your-api.railway.app

# Create installer using Inno Setup
# Open setup.iss in Inno Setup Compiler and compile
```

See [DEPLOYMENT_COMPLETE_GUIDE.md](./DEPLOYMENT_COMPLETE_GUIDE.md) for detailed instructions.

## 📱 Features

- **Employee Management** - Track employees, attendance, and salaries
- **Stock Management** - Daily and overall stock tracking
- **Production Tracking** - Daily production records
- **Expense Management** - Track daily expenses and credit details
- **Mahal Bookings** - Event booking and catering management
- **Vehicle & Driver** - License and service tracking
- **Maintenance Issues** - Track and resolve maintenance issues
- **Reports & PDFs** - Generate reports and statements

## 👥 User Roles

- **Main Admin** (password: `abinaya`) - Full access including delete privileges
- **Sub Admin** (password: `admin`) - Admin access without delete privileges
- **Sector Users** - Access limited to their sector

## 🔐 Security

- JWT-based authentication
- Role-based access control
- Password-protected admin accounts
- Secure API endpoints

## 📄 License

Private - All rights reserved

## 🤝 Support

For issues and questions, please open an issue on GitHub.

---

**Built with:** Flutter, Node.js, Express, PostgreSQL
