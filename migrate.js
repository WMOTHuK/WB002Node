// migrate.js
import { pool } from './src/config/db.config.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigrations() {
    const client = await pool.connect();
    
    try {
        console.log('🔄 Starting migrations...');
        
        // Create migrations table if not exists
        await client.query(`
            CREATE TABLE IF NOT EXISTS schema_migrations (
                id SERIAL PRIMARY KEY,
                migration_name VARCHAR(255) NOT NULL UNIQUE,
                executed_at TIMESTAMP DEFAULT NOW()
            )
        `);
        console.log('✅ Migrations table ready');
        
        // Get executed migrations
        const { rows: executed } = await client.query(
            'SELECT migration_name FROM schema_migrations'
        );
        console.log(`📋 Already executed: ${executed.length} migrations`);
        
        // Read migration files
        const migrationsDir = path.join(__dirname, 'migrations');
        
        if (!fs.existsSync(migrationsDir)) {
            console.log('📁 No migrations directory found');
            return;
        }
        
        const files = fs.readdirSync(migrationsDir)
            .filter(f => f.endsWith('.sql'))
            .sort();
        
        console.log(`📄 Found ${files.length} migration files`);
        
        let executedCount = 0;
        
        // Execute new migrations
        for (const file of files) {
            const alreadyExecuted = executed.some(e => e.migration_name === file);
            
            if (alreadyExecuted) {
                console.log(`⏭️  Skipping ${file} (already executed)`);
                continue;
            }
            
            console.log(`📝 Executing ${file}...`);
            
            const sql = fs.readFileSync(
                path.join(migrationsDir, file), 
                'utf-8'
            );
            
            await client.query('BEGIN');
            await client.query(sql);
            await client.query(
                'INSERT INTO schema_migrations (migration_name) VALUES ($1)',
                [file]
            );
            await client.query('COMMIT');
            
            console.log(`✅ ${file} completed`);
            executedCount++;
        }
        
        if (executedCount === 0) {
            console.log('✅ All migrations are up to date');
        } else {
            console.log(`\n✅ Successfully executed ${executedCount} migration(s)`);
        }
        
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('❌ Migration failed:', error.message);
        console.error('Details:', error);
        throw error;
    } finally {
        client.release();
        // Don't close pool here - it's shared with the main app
        // await pool.end();
    }
}

// Run migrations if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
    runMigrations().catch(console.error);
}

export { runMigrations };