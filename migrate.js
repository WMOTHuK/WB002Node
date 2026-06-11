// migrate.js
const fs = require('fs');
const path = require('path');
const { pool } = require('./db');

async function runMigrations() {
    const client = await pool.connect();
    
    try {
        // Создаем таблицу миграций если нет
        await client.query(`
            CREATE TABLE IF NOT EXISTS schema_migrations (
                id SERIAL PRIMARY KEY,
                migration_name VARCHAR(255) NOT NULL UNIQUE,
                executed_at TIMESTAMP DEFAULT NOW()
            )
        `);
        
        // Получаем выполненные миграции
        const { rows: executed } = await client.query(
            'SELECT migration_name FROM schema_migrations'
        );
        const executedSet = new Set(executed.map(r => r.migration_name));
        
        // Читаем файлы миграций
        const migrationsDir = path.join(__dirname, 'migrations');
        const files = fs.readdirSync(migrationsDir)
            .filter(f => f.endsWith('.sql'))
            .sort(); // 001_, 002_, ...
        
        // Выполняем новые миграции
        for (const file of files) {
            if (executedSet.has(file)) {
                console.log(`Skipping ${file} (already executed)`);
                continue;
            }
            
            console.log(`Executing ${file}...`);
            const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf-8');
            
            await client.query('BEGIN');
            await client.query(sql);
            await client.query(
                'INSERT INTO schema_migrations (migration_name) VALUES ($1)',
                [file]
            );
            await client.query('COMMIT');
            
            console.log(`✓ ${file} completed`);
        }
        
        console.log('All migrations completed!');
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Migration failed:', error);
        throw error;
    } finally {
        client.release();
    }
}

const command = process.argv[2];

switch (command) {
    case 'create':
        // создать новую миграцию
        const name = process.argv[3];
        const timestamp = Date.now();
        fs.writeFileSync(
            `migrations/${timestamp}_${name}.sql`,
            fs.readFileSync('migrations/_template.sql', 'utf-8')
        );
        console.log(`Created migration: ${timestamp}_${name}.sql`);
        break;
        
    case 'status':
        // показать статус
        const { rows } = await pool.query('SELECT * FROM schema_migrations ORDER BY id');
        console.table(rows);
        break;
        
    default:
        // выполнить миграции (как сейчас)
        await runMigrations();
}

runMigrations();