// Isolated PostgreSQL/WASM runner. No network or shared database connection.
// Expands the existing psql \ir directives and discards output-only \pset.
import { PGlite } from '@electric-sql/pglite';
import { btree_gist } from '@electric-sql/pglite/contrib/btree_gist';
import { readFile, readdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
async function sqlFile(path) {
  const source = await readFile(path, 'utf8');
  const output = [];
  for (const line of source.split('\n')) {
    if (line.startsWith('\\ir ')) output.push(await sqlFile(resolve(dirname(path), line.slice(4).trim())));
    else if (!line.startsWith('\\pset ')) output.push(line);
  }
  return output.join('\n');
}
const database = new PGlite({ extensions: { btree_gist } });
try {
  console.log((await database.query('select version()')).rows[0].version);
  await database.exec(await sqlFile(resolve(root, 'tests/local/supabase_stub.sql')));
  await database.exec('set search_path = public, extensions');
  for (const file of (await readdir(resolve(root, 'migrations'))).filter(f => f.endsWith('.sql')).sort()) {
    await database.exec('begin');
    try { await database.exec(await sqlFile(resolve(root, 'migrations', file))); await database.exec('commit'); }
    catch (error) { console.error(`Migration failed: ${file}`); throw error; }
  }
  let checks = 0;
  for (const file of (await readdir(resolve(root, 'tests'))).filter(f => f.endsWith('_test.sql')).sort()) {
    try {
      const results = await database.exec(await sqlFile(resolve(root, 'tests', file)));
      const summary = results.flatMap(r => r.rows).find(r => 'passed' in r && 'failed' in r);
      console.log(`${file}: ${summary?.passed} passed, ${summary?.failed} failed`);
      checks += Number(summary?.passed ?? 0);
    } catch (error) { console.error(`Test failed: ${file}`); throw error; }
  }
  console.log(`All ${checks} SQL checks passed.`);
} finally { await database.close(); }
