// scripts/create-migration.js
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

// Получаем __dirname в ES модулях
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Получаем имя миграции из аргументов командной строки
const args = process.argv.slice(2);
const migrationName = args[0];

if (!migrationName) {
    console.error('❌ Ошибка: укажите имя миграции');
    console.log('📝 Использование: npm run migrate:create add_overheads_batch_function');
    process.exit(1);
}

// Создаем имя файла с временной меткой
const timestamp = Date.now();
const filename = `${timestamp}_${migrationName}.sql`;
const migrationsDir = path.join(__dirname, '..', 'migrations');
const filepath = path.join(migrationsDir, filename);

// Шаблон миграции
const template = `-- ============================================================================
-- Миграция: ${migrationName}
-- Дата: ${new Date().toISOString()}
-- ============================================================================

BEGIN;

-- ${migrationName}

COMMIT;

-- Откат:
-- ROLLBACK;
`;

// Создаем директорию migrations если её нет
if (!fs.existsSync(migrationsDir)) {
    fs.mkdirSync(migrationsDir, { recursive: true });
}

// Записываем файл
fs.writeFileSync(filepath, template, 'utf8');

console.log(`✅ Создана миграция: ${filepath}`);