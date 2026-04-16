import sqlite3

conn = sqlite3.connect("rescue.db")
cursor = conn.cursor()

cursor.execute("PRAGMA table_info(surrender);")

columns = cursor.fetchall()

for col in columns:
    print(col)

conn.close()