import sqlite3

DB_NAME = "rescue.db"


def get_connection():
    return sqlite3.connect(DB_NAME)


def create_tables():

    conn = get_connection()
    cursor = conn.cursor()


    # ---------------- SHELTERS ----------------
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS shelters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'shelter',  -- 'shelter' or 'vet'
        latitude REAL NOT NULL,
        longitude REAL NOT NULL
    )
    """)

    # Seed shelters (INSERT OR IGNORE so re-runs are safe)
    cursor.executemany(""" 
        INSERT OR IGNORE INTO shelters (id, name, type, latitude, longitude)
        VALUES (?, ?, ?, ?, ?)
    """, [
        (1, "Kakkanad Rescue Shelter",   "shelter", 10.0067, 76.3460),
        (2, "Ernakulam City Shelter",    "shelter", 9.9816,  76.2999),
        (3, "Aluva Rescue Shelter",      "shelter", 10.1004, 76.3570),
        (4, "District Veterinary Hospital", "vet",  9.9312,  76.2673),
    ])


    # ---------------- CASES ----------------
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS cases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT,
        predicted_breed TEXT,
        injury_status TEXT,
        latitude REAL,
        longitude REAL,
        case_status TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
    """)

    # Migration-safe additions
    for col_def in [
        "ALTER TABLE cases ADD COLUMN shelter_id INTEGER",
        "ALTER TABLE cases ADD COLUMN ai_injury_status TEXT",
        "ALTER TABLE cases ADD COLUMN reported_injury_status TEXT",
        "ALTER TABLE cases ADD COLUMN reported_injury_type TEXT",
        "ALTER TABLE cases ADD COLUMN reported_severity TEXT",
        "ALTER TABLE cases ADD COLUMN priority TEXT DEFAULT 'NORMAL'",
        "ALTER TABLE cases ADD COLUMN vaccination_status TEXT DEFAULT 'no'",
        "ALTER TABLE cases ADD COLUMN medical_notes TEXT",
    ]:
        try:
            cursor.execute(col_def)
        except Exception:
            pass  # column already exists


    # ---------------- SURRENDER ----------------
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS surrender (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        image_path TEXT,

        reason TEXT,
        phone TEXT,
        user_name TEXT,

        behavior TEXT,
        allergies TEXT,
        food TEXT,
        breed TEXT,
        age INTEGER,
        gender TEXT,
        vaccinated TEXT,

        latitude REAL,
        longitude REAL,

        notes TEXT,

        status TEXT DEFAULT 'pending',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
    """)


    # ---------------- ADOPTION LIST ----------------
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS adoption (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        source_type TEXT,
        source_id INTEGER,

        dog_name TEXT,
        breed TEXT,
        color TEXT,
        age TEXT,
        gender TEXT,
        vaccination_status TEXT,
        behavior_description TEXT,
        location TEXT,
        image_path TEXT,

        status TEXT DEFAULT 'available',

        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
    """)

    # Migration-safe: add new fields to adoption table if not present
    for col in ["dog_name TEXT", "color TEXT", "vaccination_status TEXT", "behavior_description TEXT"]:
        try:
            cursor.execute(f"ALTER TABLE adoption ADD COLUMN {col}")
        except Exception as e:
            pass

    # ---------------- ADOPTION REQUESTS ----------------
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS adoption_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        adoption_id INTEGER,

        user_name TEXT,
        phone TEXT,
        address TEXT,

        status TEXT DEFAULT 'pending',

        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
    """)


    # ---------------- USERS ----------------
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        username TEXT UNIQUE,
        password TEXT,

        role TEXT,  -- user / shelter / vet

        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
    """)

    # Migration-safe: add shelter_id to users if not present
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN shelter_id INTEGER")
    except Exception:
        pass  # column already exists

    # Default accounts: existing super-admin + per-shelter accounts
    # Passwords are pre-hashed using Bcrypt equivalent to '1234'
    bcrypt_hash = '$2b$12$5utd8T6/25SfzwqAzgt9D.X8mRk3QVL1wfEwuDW/F3msOsy5q0/4C'
    cursor.execute("""
        INSERT OR IGNORE INTO users (username, password, role, shelter_id)
        VALUES
        ('shelter1',          ?, 'shelter', NULL),
        ('vet1',              ?, 'vet',     4),
        ('shelter_kakkanad',  ?, 'shelter', 1),
        ('shelter_ernakulam', ?, 'shelter', 2),
        ('shelter_aluva',     ?, 'shelter', 3)
    """, (bcrypt_hash, bcrypt_hash, bcrypt_hash, bcrypt_hash, bcrypt_hash))


    # ---------------- NOTIFICATIONS ----------------
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT,
        reference_id INTEGER,
        is_read INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    conn.commit()
    conn.close()
