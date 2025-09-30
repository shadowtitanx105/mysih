## Database Schema Design for Loan Utilization App

### 1. Users Table
```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  mobile_number TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('beneficiary', 'officer')),
  full_name TEXT NOT NULL,
  email TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  is_verified INTEGER DEFAULT 0,
  sync_status TEXT DEFAULT 'synced' CHECK(sync_status IN ('pending', 'synced', 'failed'))
);
```

### 2. Beneficiaries Table
```sql
CREATE TABLE beneficiaries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  beneficiary_code TEXT UNIQUE NOT NULL,
  address TEXT,
  district TEXT,
  state TEXT,
  pincode TEXT,
  aadhaar_last_four TEXT,
  bank_account TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_status TEXT DEFAULT 'synced',
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### 3. Loans Table
```sql
CREATE TABLE loans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  loan_id TEXT UNIQUE NOT NULL,
  beneficiary_id INTEGER NOT NULL,
  officer_id INTEGER,
  loan_amount REAL NOT NULL,
  loan_purpose TEXT NOT NULL,
  scheme_name TEXT NOT NULL,
  sanctioned_date INTEGER NOT NULL,
  disbursed_date INTEGER,
  status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'approved', 'disbursed', 'completed', 'rejected')),
  remarks TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_status TEXT DEFAULT 'synced',
  FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries(id) ON DELETE CASCADE,
  FOREIGN KEY (officer_id) REFERENCES users(id)
);
```

### 4. Media Submissions Table
```sql
CREATE TABLE media_submissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  submission_id TEXT UNIQUE NOT NULL,
  loan_id INTEGER NOT NULL,
  beneficiary_id INTEGER NOT NULL,
  media_type TEXT NOT NULL CHECK(media_type IN ('image', 'video')),
  file_path TEXT NOT NULL,
  file_size INTEGER,
  thumbnail_path TEXT,
  latitude REAL,
  longitude REAL,
  location_accuracy REAL,
  address TEXT,
  captured_at INTEGER NOT NULL,
  description TEXT,
  asset_category TEXT,
  status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'under_review', 'approved', 'rejected')),
  ai_validation_score REAL,
  ai_validation_result TEXT,
  officer_remarks TEXT,
  reviewed_by INTEGER,
  reviewed_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_status TEXT DEFAULT 'pending',
  server_url TEXT,
  FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE CASCADE,
  FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries(id) ON DELETE CASCADE,
  FOREIGN KEY (reviewed_by) REFERENCES users(id)
);
```

### 5. Officers Table
```sql
CREATE TABLE officers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  officer_code TEXT UNIQUE NOT NULL,
  designation TEXT,
  department TEXT,
  jurisdiction TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_status TEXT DEFAULT 'synced',
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### 6. Sync Queue Table
```sql
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL CHECK(entity_type IN ('user', 'loan', 'media', 'approval')),
  entity_id INTEGER NOT NULL,
  operation TEXT NOT NULL CHECK(operation IN ('create', 'update', 'delete')),
  data TEXT NOT NULL,
  retry_count INTEGER DEFAULT 0,
  last_error TEXT,
  created_at INTEGER NOT NULL,
  attempted_at INTEGER
);
```

### 7. OTP Verification Table
```sql
CREATE TABLE otp_verifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  mobile_number TEXT NOT NULL,
  otp_code TEXT NOT NULL,
  purpose TEXT DEFAULT 'login',
  is_verified INTEGER DEFAULT 0,
  expires_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
```

### 8. App Settings Table
```sql
CREATE TABLE app_settings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### 9. Audit Log Table
```sql
CREATE TABLE audit_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER,
  action TEXT NOT NULL,
  entity_type TEXT,
  entity_id INTEGER,
  details TEXT,
  ip_address TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

## Indexes for Performance

```sql
CREATE INDEX idx_users_mobile ON users(mobile_number);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_loans_beneficiary ON loans(beneficiary_id);
CREATE INDEX idx_loans_status ON loans(status);
CREATE INDEX idx_media_loan ON media_submissions(loan_id);
CREATE INDEX idx_media_status ON media_submissions(status);
CREATE INDEX idx_media_sync ON media_submissions(sync_status);
CREATE INDEX idx_sync_queue_entity ON sync_queue(entity_type, entity_id);
CREATE INDEX idx_sync_queue_created ON sync_queue(created_at);
```

## Key Design Decisions

1. **Offline-First**: All tables include `sync_status` field to track synchronization state
2. **Timestamps**: Using INTEGER for timestamps (Unix epoch) for better SQLite performance
3. **Foreign Keys**: Proper relationships with CASCADE deletes where appropriate
4. **Check Constraints**: Ensuring data integrity at database level
5. **Sync Queue**: Dedicated table for managing offline operations that need to be synced
6. **Audit Trail**: Complete logging of all critical operations
7. **Flexible Media**: Support for both images and videos with geolocation
8. **Role-Based Access**: Clear separation between beneficiaries and officers
