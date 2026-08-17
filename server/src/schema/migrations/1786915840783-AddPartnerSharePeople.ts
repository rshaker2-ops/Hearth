import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await sql`ALTER TABLE "partner" ADD "sharePeople" boolean NOT NULL DEFAULT false;`.execute(db);
}

export async function down(db: Kysely<any>): Promise<void> {
  await sql`ALTER TABLE "partner" DROP COLUMN "sharePeople";`.execute(db);
}
