// One-off asset uploader for Fullball. Auth via a service-account key:
//   download from Firebase console → Project settings → Service accounts →
//   Generate new private key → save as tools/upload/serviceAccount.json (gitignored).
//
// Usage (from tools/upload/):
//   node upload_assets.js images     # build/player_images/*.jpg -> Storage players/<id>.jpg
//   node upload_assets.js catalog    # Fullball/Resources/catalog.json -> Firestore catalog/current
//   node upload_assets.js all        # both
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { dirname, join, basename } from "node:path";
import { fileURLToPath } from "node:url";
import { initializeApp, cert } from "firebase-admin/app";
import { getStorage } from "firebase-admin/storage";
import { getFirestore } from "firebase-admin/firestore";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = join(HERE, "..", "..");
const BUCKET = "fullball-game.firebasestorage.app";
const KEY = process.env.GOOGLE_APPLICATION_CREDENTIALS || join(HERE, "serviceAccount.json");

if (!existsSync(KEY)) {
  console.error(`✗ service-account key not found at ${KEY}\n  Download it (console → Service accounts → Generate new private key) and save as tools/upload/serviceAccount.json`);
  process.exit(1);
}
initializeApp({ credential: cert(JSON.parse(readFileSync(KEY, "utf8"))), storageBucket: BUCKET });

async function uploadImages() {
  const dir = join(REPO, "build", "player_images");
  if (!existsSync(dir)) { console.error(`✗ ${dir} missing — run tools/process_players.sh first`); process.exit(1); }
  const files = readdirSync(dir).filter(f => f.endsWith(".jpg"));
  const bucket = getStorage().bucket();
  let n = 0;
  for (const f of files) {
    const id = basename(f, ".jpg");
    await bucket.upload(join(dir, f), {
      destination: `players/${id}.jpg`,
      metadata: { contentType: "image/jpeg", cacheControl: "public,max-age=31536000" },
    });
    n++; process.stdout.write(`\r↑ images ${n}/${files.length}`);
  }
  console.log(`\n✓ uploaded ${n} portraits to gs://${BUCKET}/players/`);
}

async function uploadCatalog() {
  const path = join(REPO, "Fullball", "Resources", "catalog.json");
  const catalog = JSON.parse(readFileSync(path, "utf8"));
  await getFirestore().collection("catalog").doc("current").set(catalog);
  console.log(`✓ wrote catalog/current (${catalog.cards.length} cards, ${catalog.nations.length} nations)`);
}

const cmd = process.argv[2] || "all";
if (cmd === "images") await uploadImages();
else if (cmd === "catalog") await uploadCatalog();
else if (cmd === "all") { await uploadImages(); await uploadCatalog(); }
else { console.error(`unknown command '${cmd}' (use: images | catalog | all)`); process.exit(1); }
process.exit(0);
