/**
 * One-off script: delete users by UUID from the `users` table.
 * Run from backend_app: npx ts-node scripts/delete-users-by-uuid.ts
 * Requires .env with DB_HOST, DB_PORT, DB_USERNAME, DB_PASSWORD, DB_NAME.
 */
import { config } from 'dotenv';
import { resolve } from 'path';
import { Client } from 'pg';

// Load .env from backend_app root
config({ path: resolve(__dirname, '..', '.env') });

const UUIDS = [
  '3da84734-88bc-4f27-9d62-a50863bf2667',
  'd4d20708-0b5a-4afb-ba45-c66a5b57e663',
  '7c7a1469-4496-447c-9744-5b8ec8c05931',
];

async function main() {
  const client = new Client({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT) || 5432,
    user: process.env.DB_USERNAME || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    database: process.env.DB_NAME || 'assignment_db',
  });

  await client.connect();

  const res = await client.query(
    'DELETE FROM users WHERE id = ANY($1::uuid[]) RETURNING id',
    [UUIDS],
  );

  console.log(`Deleted ${res.rowCount} user(s):`, res.rows.map((r) => r.id));
  await client.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
