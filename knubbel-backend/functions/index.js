const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.deleteOldGames = functions.pubsub.schedule("every 1 hours").onRun(async (context) => {
    const db = admin.firestore();
    const gamesRef = db.collection("games");
    const now = Date.now();
    const cutoff = now - 24 * 60 * 60 * 1000; // 24 Stunden in Millisekunden

    const snapshot = await gamesRef.where("createdAt", "<", new Date(cutoff)).get();

    const deletions = snapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(deletions);

    console.log(`✅ ${deletions.length} alte Spiele gelöscht.`);
});
