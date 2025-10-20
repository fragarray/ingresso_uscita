#!/bin/bash
# Fix rapido - Una sola riga di comando

echo "🔧 Fix database schema..."
cd ~/ingresso_uscita_server
cp database.db database_backup_$(date +%Y%m%d_%H%M%S).db
sqlite3 database.db << 'EOF'
ALTER TABLE employees ADD COLUMN username TEXT UNIQUE;
ALTER TABLE employees ADD COLUMN role TEXT DEFAULT 'employee';
ALTER TABLE employees ADD COLUMN isActive INTEGER DEFAULT 1;
ALTER TABLE employees ADD COLUMN allowNightShift INTEGER DEFAULT 0;
ALTER TABLE employees ADD COLUMN deleted INTEGER DEFAULT 0;
ALTER TABLE employees ADD COLUMN deletedAt DATETIME;
ALTER TABLE employees ADD COLUMN deletedByAdminId INTEGER;
INSERT OR IGNORE INTO employees (name, username, email, password, isAdmin, role, isActive) VALUES ('Admin', 'admin', 'admin@example.com', 'admin123', 1, 'admin', 1);
EOF
echo "✅ Fix completato!"
echo "📋 Credenziali: username=admin password=admin123"
echo "🔄 Riavvia: sudo systemctl restart ingresso-uscita"
