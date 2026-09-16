const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
const ADMIN_UID = "WBdQVvrgEIPBTcgIlumu6bAZGUl2";
const FALLBACK_DELAY_MS = 3 * 1000;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function safeText(value, max = 4000) {
  return String(value ?? "").trim().slice(0, max);
}

async function callSupportAi({ message, locale, history }) {
  const apiKey = OPENAI_API_KEY.value();
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY is not configured");
  }

  const isEnglish = locale === "en";
  const systemPrompt = isEnglish
    ? [
        "You are Sesan Support AI, the fallback assistant inside Sesan App.",
        "Help users with Sesan App usage, account navigation, posting products, search, chat, orders, seller mode, wallet UI explanations, and general support.",
        "Be concise, practical, and friendly.",
        "Never pretend to be a human admin.",
        "Never claim you changed an order, payment, wallet balance, account status, or other backend data unless an actual tool/action confirmed it.",
        "For payment, withdrawal, order disputes, account ownership, refunds, bans, or anything sensitive, explain safe next steps and say a human Sesan Support admin will review it.",
        "Do not reveal internal secrets, keys, admin identifiers, or security logic.",
      ].join(" ")
    : [
        "អ្នកគឺ Sesan Support AI ដែលជាជំនួយការបម្រុងនៅក្នុង Sesan App។",
        "ជួយអ្នកប្រើអំពីរបៀបប្រើ App គណនី ការបង្ហោះទំនិញ ស្វែងរក ឆាត ការបញ្ជាទិញ Seller Mode Wallet UI និងសំណួរ Support ទូទៅ។",
        "ឆ្លើយឱ្យខ្លី ច្បាស់ និងអនុវត្តបាន។",
        "កុំធ្វើខ្លួនថាជា Admin មនុស្ស។",
        "កុំអះអាងថាបានកែ Order Payment Wallet Balance Account Status ឬទិន្នន័យ Backend ប្រសិនបើគ្មាន Action ពិតប្រាកដបញ្ជាក់។",
        "បើពាក់ព័ន្ធ Payment Withdrawal Order dispute Account ownership Refund Ban ឬបញ្ហាសំខាន់ សូមណែនាំជំហានសុវត្ថិភាព ហើយប្រាប់ថា Sesan Support Admin មនុស្សនឹងពិនិត្យបន្ត។",
        "កុំបង្ហាញ Secret Key Admin ID ឬ Security Logic ខាងក្នុង។",
      ].join(" ");

  const messages = [
    { role: "system", content: systemPrompt },
    ...history.map((item) => ({
      role: item.role === "assistant" ? "assistant" : "user",
      content: safeText(item.content, 1200),
    })),
    { role: "user", content: safeText(message, 2000) },
  ];

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      messages,
      temperature: 0.3,
      max_tokens: 500,
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`OpenAI ${response.status}: ${detail.slice(0, 500)}`);
  }

  const data = await response.json();
  const answer = safeText(data?.choices?.[0]?.message?.content, 5000);
  if (!answer) throw new Error("Empty support AI response");
  return answer;
}

exports.supportAiFallback = onDocumentCreated(
  {
    document: "support_chats/{userId}/messages/{messageId}",
    region: "asia-southeast1",
    secrets: [OPENAI_API_KEY],
    timeoutSeconds: 120,
    memory: "256MiB",
    maxInstances: 10,
  },
  async (event) => {
    const messageData = event.data?.data() || {};
    const userId = String(event.params.userId || "").trim();
    const messageId = String(event.params.messageId || "").trim();

    if (!userId || !messageId) return null;
    if (messageData.senderType !== "user") return null;

    const text = safeText(messageData.text, 2000);
    if (!text || text === "📷 Image" || text === "📷 រូបភាព") return null;

    const db = admin.firestore();
    const threadRef = db.collection("support_chats").doc(userId);
    const messagesRef = threadRef.collection("messages");

    await sleep(FALLBACK_DELAY_MS);

    const adminSnap = await db.collection("users").doc(ADMIN_UID).get();
    const adminOnline = adminSnap.exists && adminSnap.data()?.isOnline === true;

    const triggerSnap = await event.data.ref.get();
    if (!triggerSnap.exists) return null;
    const triggerCreatedAt = triggerSnap.data()?.createdAt;
    if (!triggerCreatedAt) {
      console.log("Support AI skipped because trigger timestamp is missing", userId, messageId);
      return null;
    }

    const laterMessages = await messagesRef
      .where("createdAt", ">", triggerCreatedAt)
      .orderBy("createdAt", "asc")
      .limit(30)
      .get();

    const humanAlreadyReplied = laterMessages.docs.some(
      (doc) => doc.data()?.senderType === "admin"
    );
    if (humanAlreadyReplied) {
      console.log("Support AI skipped because Admin already replied to this message", userId);
      return null;
    }

    if (adminOnline) {
      const recentForHandoff = await messagesRef
        .orderBy("createdAt", "desc")
        .limit(30)
        .get();
      const adminHasJoined = recentForHandoff.docs.some(
        (doc) => doc.data()?.senderType === "admin"
      );
      if (adminHasJoined) {
        console.log("Support AI paused while Admin is handling the thread", userId);
        return null;
      }
    }

    const newerUserMessageExists = laterMessages.docs.some(
      (doc) => doc.data()?.senderType === "user"
    );
    if (newerUserMessageExists) {
      console.log("Support AI skipped older user message; newer message exists", userId, messageId);
      return null;
    }

    const existingFallback = await messagesRef
      .where("fallbackForMessageId", "==", messageId)
      .limit(1)
      .get();
    if (!existingFallback.empty) {
      console.log("Support AI reply already exists", userId, messageId);
      return null;
    }

    const recentSnap = await messagesRef
      .orderBy("createdAt", "desc")
      .limit(12)
      .get();

    const recent = recentSnap.docs
      .map((doc) => doc.data() || {})
      .reverse()
      .filter((item) => item.senderType === "user" || item.senderType === "ai")
      .map((item) => ({
        role: item.senderType === "ai" ? "assistant" : "user",
        content: safeText(item.text, 1200),
      }))
      .filter((item) => item.content);

    const userSnap = await db.collection("users").doc(userId).get();
    const locale = String(userSnap.data()?.languageCode || userSnap.data()?.language || "km")
      .toLowerCase()
      .startsWith("en")
      ? "en"
      : "km";

    try {
      const answer = await callSupportAi({
        message: text,
        locale,
        history: recent.slice(0, -1),
      });

      const postAiCheck = await messagesRef
        .where("createdAt", ">", triggerCreatedAt)
        .orderBy("createdAt", "asc")
        .limit(30)
        .get();
      if (postAiCheck.docs.some((doc) => doc.data()?.senderType === "admin")) {
        console.log("Support AI discarded because Admin replied during generation", userId);
        return null;
      }

      await messagesRef.add({
        senderId: "support_ai",
        senderType: "ai",
        text: answer,
        imageUrl: "",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        fallbackForMessageId: messageId,
        aiMode: "support_free",
        freeSupportAi: true,
      });

      await threadRef.set(
        {
          lastMessage: answer,
          lastSenderType: "ai",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          userUnread: admin.firestore.FieldValue.increment(1),
          aiFallbackAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      console.log("Support AI fallback replied", userId, messageId);
    } catch (error) {
      console.error("Support AI fallback failed", userId, messageId, error);
      await threadRef.set(
        {
          aiFallbackErrorAt: admin.firestore.FieldValue.serverTimestamp(),
          aiFallbackError: safeText(error?.message || error, 500),
        },
        { merge: true }
      );
    }

    return null;
  }
);
