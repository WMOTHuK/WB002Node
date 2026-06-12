// scripts/validate-migration.js
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const args = process.argv.slice(2);
const migrationFile = args[0];

if (!migrationFile) {
    console.error('❌ Please specify migration file');
    console.log('📝 Usage: node scripts/validate-migration.js migrations/001_initial_schema.sql');
    process.exit(1);
}

const filePath = path.join(process.cwd(), migrationFile);

if (!fs.existsSync(filePath)) {
    console.error(`❌ File not found: ${filePath}`);
    process.exit(1);
}

const content = fs.readFileSync(filePath, 'utf-8');
const lines = content.split('\n');

console.log(`\n🔍 Validating: ${migrationFile}\n`);

let hasErrors = false;
let errorCount = 0;
let warningCount = 0;

// Check 1: Look for psql meta-commands (lines starting with \)
console.log('📌 Check 1: psql meta-commands (\\d, \\dt, \\connect, etc.)');
lines.forEach((line, index) => {
    const trimmed = line.trim();
    if (trimmed.startsWith('\\') && !trimmed.startsWith('--')) {
        console.log(`   ❌ Line ${index + 1}: ${trimmed.substring(0, 50)}...`);
        console.log(`      psql meta-commands are not allowed in migration files`);
        hasErrors = true;
        errorCount++;
    }
});
if (errorCount === 0) console.log('   ✅ No psql meta-commands found');

// Check 2: Look for invalid escape sequences
console.log('\n📌 Check 2: Invalid escape sequences');
const invalidEscapes = content.match(/[^\\]\\(?!n|t|r|\\|'|")/g);
if (invalidEscapes) {
    console.log(`   ⚠️  Found ${invalidEscapes.length} potential invalid escape sequences`);
    warningCount += invalidEscapes.length;
} else {
    console.log('   ✅ No invalid escape sequences found');
}

// Check 3: Look for non-UTF8 characters (control chars, etc.)
console.log('\n📌 Check 3: Non-UTF8 characters');
const nonUtf8 = content.match(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g);
if (nonUtf8) {
    console.log(`   ❌ Found ${nonUtf8.length} control characters (non-UTF8)`);
    hasErrors = true;
    errorCount += nonUtf8.length;
} else {
    console.log('   ✅ No non-UTF8 characters found');
}

// Check 4: Check for unbalanced quotes
console.log('\n📌 Check 4: Balanced quotes');
let inString = false;
let stringChar = '';
let unbalancedLine = -1;

for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    let inLineString = false;
    let lineStringChar = '';
    
    for (let j = 0; j < line.length; j++) {
        const char = line[j];
        const prevChar = j > 0 ? line[j-1] : '';
        
        if ((char === "'" || char === '"') && prevChar !== '\\') {
            if (!inString && !inLineString) {
                inString = true;
                inLineString = true;
                stringChar = char;
                lineStringChar = char;
                unbalancedLine = i + 1;
            } else if ((inString && char === stringChar) || (inLineString && char === lineStringChar)) {
                inString = false;
                inLineString = false;
                unbalancedLine = -1;
            }
        }
    }
}

if (unbalancedLine !== -1) {
    console.log(`   ⚠️  Possible unbalanced quotes near line ${unbalancedLine}`);
    warningCount++;
} else {
    console.log('   ✅ Quotes appear balanced');
}

// Check 5: Check for BEGIN/COMMIT balance
console.log('\n📌 Check 5: BEGIN/COMMIT balance');
const beginCount = (content.match(/\bBEGIN\b/gi) || []).length;
const commitCount = (content.match(/\bCOMMIT\b/gi) || []).length;
const rollbackCount = (content.match(/\bROLLBACK\b/gi) || []).length;

console.log(`   BEGIN: ${beginCount}, COMMIT: ${commitCount}, ROLLBACK: ${rollbackCount}`);

if (beginCount !== commitCount + rollbackCount) {
    console.log(`   ⚠️  Unbalanced transactions (BEGIN: ${beginCount}, COMMIT: ${commitCount})`);
    warningCount++;
} else if (beginCount === 0) {
    console.log('   ⚠️  No transaction wrapper found (recommended to use BEGIN/COMMIT)');
    warningCount++;
} else {
    console.log('   ✅ Transactions are balanced');
}

// Check 6: Check for problematic SQL keywords without proper context
console.log('\n📌 Check 6: Potentially problematic patterns');
const problematicPatterns = [
    { pattern: /\\restrict/i, name: 'restrict command' },
    { pattern: /\\connect/i, name: 'connect command' },
    { pattern: /\\c\s+\w+/i, name: '\\c (connect) command' },
    { pattern: /\\echo/i, name: 'echo command' },
    { pattern: /\\i\s+/i, name: 'include command' },
    { pattern: /\\ir\s+/i, name: 'include relative command' },
    { pattern: /\\o\s+/i, name: 'output command' },
    { pattern: /\\copy/i, name: 'copy command (use COPY instead)' },
];

problematicPatterns.forEach(({ pattern, name }) => {
    if (pattern.test(content)) {
        console.log(`   ⚠️  Found: ${name}`);
        warningCount++;
    }
});

if (warningCount === 0) console.log('   ✅ No problematic patterns found');

// Check 7: Check file encoding
console.log('\n📌 Check 7: File encoding');
const buffer = fs.readFileSync(filePath);
const isUtf8 = buffer.toString('utf8').length === buffer.length;
if (!isUtf8) {
    console.log('   ⚠️  File may not be valid UTF-8');
    warningCount++;
} else {
    console.log('   ✅ File is valid UTF-8');
}

// Summary
console.log('\n' + '='.repeat(50));
console.log('📊 SUMMARY');
console.log('='.repeat(50));

if (errorCount > 0) {
    console.log(`❌ ERRORS: ${errorCount} - Migration should NOT be executed`);
} else {
    console.log(`✅ No critical errors found`);
}

if (warningCount > 0) {
    console.log(`⚠️  WARNINGS: ${warningCount} - Review suggested`);
} else {
    console.log(`✅ No warnings`);
}

console.log(`\n📄 File size: ${(buffer.length / 1024).toFixed(2)} KB`);
console.log(`📝 Lines: ${lines.length}`);

if (errorCount === 0) {
    console.log('\n✅ Migration validation passed!\n');
    process.exit(0);
} else {
    console.log('\n❌ Migration validation failed!\n');
    process.exit(1);
}
