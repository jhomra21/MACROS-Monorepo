CREATE TABLE IF NOT EXISTS waitlist_entries (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	email TEXT NOT NULL,
	created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_waitlist_entries_email
	ON waitlist_entries(email);

CREATE INDEX IF NOT EXISTS idx_waitlist_entries_created_at
	ON waitlist_entries(created_at DESC);
