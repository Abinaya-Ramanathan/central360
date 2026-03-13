# Login credentials

**There is no database table that stores login credentials.**

Logins are validated in code in **`backend/src/routes/auth.routes.js`**:

- **Admin:** password `surya` or `abinaya` (case insensitive). Username is not checked.
- **Sector (keyword) logins:** password is one of: `cafe`, `crusher`, `mahal`, `bunk`, `ricemill`, `farm`. Each keyword maps to one or more sector codes; the user then sees only those sectors.
- Password `admin` is rejected (wrong credentials).

No user/password table is used; the backend does not persist or look up credentials in the database.
