import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/constants.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users Table
    await db.execute('''
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
      )
    ''');

    // Beneficiaries Table
    await db.execute('''
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
      )
    ''');

    // Loans Table
    await db.execute('''
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
        created_by INTEGER NOT NULL,
        created_by_role TEXT NOT NULL,
        updated_by INTEGER,
        updated_by_role TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status TEXT DEFAULT 'synced',
        sync_attempts INTEGER DEFAULT 0,
        last_sync_error TEXT,
        firestore_id TEXT,
        FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries(id) ON DELETE CASCADE,
        FOREIGN KEY (officer_id) REFERENCES users(id),
        FOREIGN KEY (created_by) REFERENCES users(id),
        FOREIGN KEY (updated_by) REFERENCES users(id)
      )
    ''');

    // Media Submissions Table
    await db.execute('''
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
        reviewed_by_role TEXT,
        reviewed_at INTEGER,
        created_by INTEGER NOT NULL,
        created_by_role TEXT NOT NULL,
        updated_by INTEGER,
        updated_by_role TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        sync_attempts INTEGER DEFAULT 0,
        last_sync_error TEXT,
        server_url TEXT,
        firestore_id TEXT,
        FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE CASCADE,
        FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries(id) ON DELETE CASCADE,
        FOREIGN KEY (reviewed_by) REFERENCES users(id),
        FOREIGN KEY (created_by) REFERENCES users(id),
        FOREIGN KEY (updated_by) REFERENCES users(id)
      )
    ''');

    // Officers Table
    await db.execute('''
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
      )
    ''');

    // Sync Queue Table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL CHECK(entity_type IN ('user', 'loan', 'media', 'approval')),
        entity_id INTEGER NOT NULL,
        operation TEXT NOT NULL CHECK(operation IN ('create', 'update', 'delete')),
        data TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        user_role TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at INTEGER NOT NULL,
        attempted_at INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // OTP Verification Table
    await db.execute('''
      CREATE TABLE otp_verifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mobile_number TEXT NOT NULL,
        otp_code TEXT NOT NULL,
        purpose TEXT DEFAULT 'login',
        is_verified INTEGER DEFAULT 0,
        expires_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // App Settings Table
    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Audit Logs Table
    await db.execute('''
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
      )
    ''');

    // Create Indexes
    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX idx_users_mobile ON users(mobile_number)');
    await db.execute('CREATE INDEX idx_users_role ON users(role)');
    await db.execute('CREATE INDEX idx_loans_beneficiary ON loans(beneficiary_id)');
    await db.execute('CREATE INDEX idx_loans_status ON loans(status)');
    await db.execute('CREATE INDEX idx_media_loan ON media_submissions(loan_id)');
    await db.execute('CREATE INDEX idx_media_status ON media_submissions(status)');
    await db.execute('CREATE INDEX idx_media_sync ON media_submissions(sync_status)');
    await db.execute('CREATE INDEX idx_sync_queue_entity ON sync_queue(entity_type, entity_id)');
    await db.execute('CREATE INDEX idx_sync_queue_created ON sync_queue(created_at)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (oldVersion < 2 && newVersion >= 2) {
      // Migration from v1 to v2: Add role-based tracking fields
      print('Migrating database from v$oldVersion to v$newVersion');
      
      // Add new columns to loans table
      await db.execute('ALTER TABLE loans ADD COLUMN created_by INTEGER');
      await db.execute('ALTER TABLE loans ADD COLUMN created_by_role TEXT');
      await db.execute('ALTER TABLE loans ADD COLUMN updated_by INTEGER');
      await db.execute('ALTER TABLE loans ADD COLUMN updated_by_role TEXT');
      await db.execute('ALTER TABLE loans ADD COLUMN sync_attempts INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE loans ADD COLUMN last_sync_error TEXT');
      await db.execute('ALTER TABLE loans ADD COLUMN firestore_id TEXT');
      
      // Add new columns to media_submissions table
      await db.execute('ALTER TABLE media_submissions ADD COLUMN reviewed_by_role TEXT');
      await db.execute('ALTER TABLE media_submissions ADD COLUMN created_by INTEGER');
      await db.execute('ALTER TABLE media_submissions ADD COLUMN created_by_role TEXT');
      await db.execute('ALTER TABLE media_submissions ADD COLUMN updated_by INTEGER');
      await db.execute('ALTER TABLE media_submissions ADD COLUMN updated_by_role TEXT');
      await db.execute('ALTER TABLE media_submissions ADD COLUMN sync_attempts INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE media_submissions ADD COLUMN last_sync_error TEXT');
      await db.execute('ALTER TABLE media_submissions ADD COLUMN firestore_id TEXT');
      
      // Add new columns to sync_queue table
      await db.execute('ALTER TABLE sync_queue ADD COLUMN user_id INTEGER');
      await db.execute('ALTER TABLE sync_queue ADD COLUMN user_role TEXT');
      
      // Populate created_by fields with officer_id where applicable
      await db.execute('''
        UPDATE loans 
        SET created_by = officer_id, 
            created_by_role = 'officer',
            updated_by = officer_id,
            updated_by_role = 'officer'
        WHERE officer_id IS NOT NULL AND created_by IS NULL
      ''');
      
      await db.execute('''
        UPDATE media_submissions 
        SET created_by = beneficiary_id,
            created_by_role = 'beneficiary'
        WHERE created_by IS NULL
      ''');
      
      print('Database migration completed successfully');
    }
  }

  // Helper method to insert data
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  // Helper method to query data
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  // Helper method to update data
  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(
      table,
      data,
      where: where,
      whereArgs: whereArgs,
    );
  }

  // Helper method to delete data
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  // Helper method for raw queries
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  // Helper method for raw inserts/updates
  Future<int> rawInsert(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawInsert(sql, arguments);
  }

  // Clear all data (for logout)
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('audit_logs');
      await txn.delete('sync_queue');
      await txn.delete('media_submissions');
      await txn.delete('loans');
      await txn.delete('officers');
      await txn.delete('beneficiaries');
      await txn.delete('users');
      await txn.delete('otp_verifications');
    });
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
