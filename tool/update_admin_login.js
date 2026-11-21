#!/usr/bin/env node
/**
 * One-off admin tool (NOT shipped with the portal): changes a portal admin's
 * Firebase sign-in email and/or password. The uid stays the same, so the
 * Firestore platform_admins/{uid} doc, the Supabase role claim and the
 * Supabase public.platform_admins row all keep working.
 *
 * Usage (from this tool/ folder, after `npm install`):
 *   node update_admin_login.js <service-account.json> <current-email> [--email <new-email>] [--password]
 *
 * --password prompts for the new password (typed twice, not echoed), so it
 * never lands in your shell history.
 *
 * After it runs, sign in to the portal again with the new details: a
 * password change signs the admin out of existing sessions.
 */
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const admin = require('firebase-admin');

function askHidden(question) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.stdoutMuted = true;
    rl._writeToOutput = (s) => {
      if (!rl.stdoutMuted || s.includes(question)) rl.output.write(s);
    };
    rl.question(question, (answer) => {
      rl.close();
      process.stdout.write('\n');
      resolve(answer);
    });
  });
}

async function main() {
  const args = process.argv.slice(2);
  const [keyPath, currentEmail] = args;
  const emailIndex = args.indexOf('--email');
  const newEmail = emailIndex > -1 ? args[emailIndex + 1] : undefined;
  const changePassword = args.includes('--password');

  if (!keyPath || !currentEmail || (!newEmail && !changePassword)) {
    console.error(
      'Usage: node update_admin_login.js <service-account.json> <current-email> [--email <new-email>] [--password]',
    );
    process.exit(1);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(path.resolve(keyPath), 'utf8'));
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

  const user = await admin.auth().getUserByEmail(currentEmail);
  const isAdmin = await admin.firestore().doc(`platform_admins/${user.uid}`).get();
  if (!isAdmin.exists) {
    console.error(`✘ ${currentEmail} (${user.uid}) is not a portal admin. Nothing changed.`);
    process.exit(1);
  }

  const update = {};
  if (newEmail) update.email = newEmail.trim();
  if (changePassword) {
    const p1 = await askHidden('New password: ');
    const p2 = await askHidden('Repeat new password: ');
    if (p1 !== p2) {
      console.error('✘ Passwords do not match. Nothing changed.');
      process.exit(1);
    }
    if (p1.length < 8) {
      console.error('✘ Use at least 8 characters. Nothing changed.');
      process.exit(1);
    }
    update.password = p1;
  }

  await admin.auth().updateUser(user.uid, update);
  console.log(`✔ Updated ${user.uid}:${newEmail ? ` email → ${update.email}` : ''}${changePassword ? ' password changed' : ''}`);
  console.log('  Custom claims kept:', JSON.stringify(user.customClaims || {}));
  if (newEmail) {
    const safe = update.email.replace(/'/g, "''");
    console.log('\nOptional, to keep the Supabase label tidy (run in the SQL editor):');
    console.log(`update public.platform_admins set email = '${safe}' where firebase_uid = '${user.uid}';`);
  }
  console.log('\nNow sign in to the portal with the new details.');
  process.exit(0);
}

main().catch((e) => {
  console.error('✘', e.message);
  process.exit(1);
});
