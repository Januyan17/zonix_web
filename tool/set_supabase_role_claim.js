#!/usr/bin/env node
/**
 * One-off admin tool (NOT shipped with the portal): gives Firebase users the
 * custom claim `role: "authenticated"`, which Supabase Third-Party Auth needs
 * before it accepts their Firebase ID token. Existing custom claims are kept.
 *
 * Usage (from this tool/ folder):
 *   npm install
 *   node set_supabase_role_claim.js <service-account.json> <uid> [<uid> ...]
 *
 * The service-account JSON comes from Firebase Console → Project settings →
 * Service accounts → Generate new private key (project zonix-93c4a). Keep it
 * out of git, and never put it (or the Supabase service_role key) in the
 * portal.
 *
 * IMPORTANT: a claim only reaches the portal in a NEW ID token. The admin
 * must sign out and back in (signing in forces a token refresh), or the
 * token must be force-refreshed, before Supabase sees the claim.
 *
 * For each uid it also prints the SQL to add the admin to
 * public.platform_admins — run that in the Supabase SQL editor.
 */
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

async function main() {
  const [keyPath, ...uids] = process.argv.slice(2);
  if (!keyPath || uids.length === 0) {
    console.error(
      'Usage: node set_supabase_role_claim.js <service-account.json> <uid> [<uid> ...]',
    );
    process.exit(1);
  }

  const serviceAccount = JSON.parse(
    fs.readFileSync(path.resolve(keyPath), 'utf8'),
  );
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

  const sql = [];
  let failed = 0;
  for (const uid of uids) {
    try {
      const user = await admin.auth().getUser(uid);
      const claims = { ...(user.customClaims || {}), role: 'authenticated' };
      await admin.auth().setCustomUserClaims(uid, claims);
      console.log(`✔ ${uid} (${user.email || 'no email'}): claims now ${JSON.stringify(claims)}`);
      const email = user.email ? `'${user.email.replace(/'/g, "''")}'` : 'null';
      sql.push(
        `insert into public.platform_admins (firebase_uid, email) values ('${uid}', ${email}) on conflict do nothing;`,
      );
    } catch (error) {
      failed++;
      console.error(`✘ ${uid}: ${error.message}`);
    }
  }

  if (sql.length) {
    console.log('\nRun in the Supabase SQL editor:\n');
    console.log(sql.join('\n'));
    console.log(
      '\nThen sign out of the portal and back in so the new claim is in the token.',
    );
  }
  process.exit(failed ? 1 : 0);
}

main();
