const {onDocumentUpdated, onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const functions = require("firebase-functions");

if (admin.apps.length === 0) {
    admin.initializeApp();
}

// ... បន្តទៅមុខទៀត

// 🔔 មុខងារជូនដំណឹងទៅ Seller ពេលមានការបញ្ជាក់ការកម្ម៉ង់ (Status: confirmed)
exports.notifySellerOnConfirmedOrder = onDocumentUpdated({
    document: "orders/{orderId}",
    region: "asia-southeast1"
}, async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const sellerId = afterData.seller_id;

    if (beforeData.status !== "confirmed" && afterData.status === "confirmed") {
        if (!sellerId) return null;

        try {
            const sellerDoc = await admin.firestore().collection("users").doc(sellerId).get();
            const token = sellerDoc.data()?.fcmToken;

            if (token) {
                await admin.messaging().send({
                    token: token,
                    notification: {
                        title: "មានការកម្ម៉ង់ថ្មី! 🚀",
                        body: "មានអតិថិជនកម្ម៉ង់ទំនិញថ្មី!",
                    },
                    android: {
                        priority: "high",
                        notification: {
                            channelId: "high_importance_channel", 
                            icon: 'ic_stat_sesan',
                            color: '#FF4500',
                            sound: "default",
                            clickAction: "FLUTTER_NOTIFICATION_CLICK",
                        }
                    }
                });
                console.log("Notification sent to seller:", sellerId);
            }
        } catch (error) {
            console.error("Error sending notification:", error);
        }
    }
    return null;
});

exports.handleOrderTrackingNotifications = onDocumentUpdated({
    document: "orders/{orderId}",
    region: "asia-southeast1"
}, async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const customerId = afterData.customer_id;

    if (!customerId) return null;

    try {
        const customerDoc = await admin.firestore().collection("users").doc(customerId).get();
        const token = customerDoc.data()?.fcmToken;

        if (token) {
            let title = "";
            let body = "";

            if (beforeData.status !== "packing" && afterData.status === "packing") {
                title = "ការកម្ម៉ង់ត្រូវបានទទួល!";
                body = "ការកម្ម៉ង់របស់បងត្រូវបានទទួលនិងកំពុងវិចខ្ចប់!";
            } else if (beforeData.status !== "on_delivery" && afterData.status === "on_delivery") {
                title = "ទំនិញកំពុងដឹកជញ្ជូន!";
                body = "ទំនិញបងបានដាក់ផ្ញើនិងដឹកជញ្ជូន!";
            } else if (beforeData.status !== "delivered" && afterData.status === "delivered") {
                title = "ទំនិញមកដល់ហើយ!";
                body = "ទំនិញបងបានមកដល់ទីតាំងហើយ";
            }

            if (title !== "") {
                await admin.messaging().send({
                    notification: { title, body },
                    android: {
                        priority: "high",
                        notification: {
                            channelId: "order_channel", 
                            icon: 'ic_stat_sesan',
                            color: '#FF4500',
                            sound: "default",
                            clickAction: "FLUTTER_NOTIFICATION_CLICK",
                        }
                    },
                    token: token
                });
            }
        }
    } catch (error) {
        console.error("Error Notification:", error);
    }
    return null;
});

exports.secureWithdraw = onCall({ region: "asia-southeast1" }, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'សូមចូលគណនីជាមុនសិន!');
    }

    const uid = request.auth.uid;
    const amount = request.data.amount;
    const pin = request.data.pin;

    const userRef = admin.firestore().collection('users').doc(uid);

    try {
        return await admin.firestore().runTransaction(async (transaction) => {
            const userDoc = await transaction.get(userRef);
            if (!userDoc.exists) throw new HttpsError('not-found', 'រកមិនឃើញអ្នកប្រើប្រាស់!');

            const userData = userDoc.data();
            if (!pin || String(pin) !== String(userData.password)) {
                throw new HttpsError('permission-denied', 'លេខសម្ងាត់មិនត្រឹមត្រូវ!');
            }

            const currentBalance = userData.balance || 0; 
            if (amount <= 0 || amount > currentBalance) {
                throw new HttpsError('invalid-argument', 'សមតុល្យមិនគ្រប់គ្រាន់!');
            }
            transaction.update(userRef, {
                balance: admin.firestore.FieldValue.increment(-amount),
                total_withdraw: admin.firestore.FieldValue.increment(amount)
            });

            const withdrawRef = admin.firestore().collection('withdraw_requests').doc();
            transaction.set(withdrawRef, {
                seller_id: uid,
                amount: amount,
                status: 'pending',
                created_at: admin.firestore.FieldValue.serverTimestamp()
            });

            return { success: true, message: "សំណើដកប្រាក់ជោគជ័យ!" };
        });
    } catch (error) {
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', error.message);
    }
});

exports.sendSellerNotification = onCall(async (request) => {
    const { sellerId, title, body } = request.data;

    try {
        const userDoc = await admin.firestore().collection('users').doc(sellerId).get();
        const userData = userDoc.data();

        if (!userData || !userData.fcmToken) {
            console.log("រកមិនឃើញ Token របស់អ្នកលក់ឡើយ");
            return { success: false, error: "No token found" };
        }

        const message = {
            notification: {
                title: title,
                body: body
            },
            android: {
                priority: "high",
                notification: {
                    channelId: "high_importance_channel", 
                    icon: 'ic_stat_sesan',
                    color: '#FF4500',
                    sound: "default",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                }
            },
            token: userData.fcmToken,   
        };

        const response = await admin.messaging().send(message);
        console.log("Notification បានផ្ញើជោគជ័យ:", response);
        return { success: true };

    } catch (error) {
        console.error("កំហុសក្នុងការផ្ញើ Noti:", error);
        throw new HttpsError("internal", error.message);
    }
});

exports.testWalletNow = onDocumentUpdated({
    document: "orders/{orderId}",
    region: "asia-southeast1"
}, async (event) => {
    const db = admin.firestore();
    const orderData = event.data.after.data();
    console.log("--- ចាប់ផ្ដើមតេស្ត Logic ៥ ថ្ងៃ ---");
    const now = new Date();
    const packingDate = orderData.packing_date ? orderData.packing_date.toDate() : new Date();
    console.log("ម៉ោងឥឡូវ (Server):", now.toISOString());
    console.log("ម៉ោងក្នុងបុង (Packing Date):", packingDate.toISOString());

    const diffInMs = now.getTime() - packingDate.getTime();
    const fiveDaysInMs = 5 * 24 * 60 * 60 * 1000;

    if (diffInMs >= fiveDaysInMs && orderData.is_settled === false) {
        console.log("✅ គ្រប់លក្ខខណ្ឌ ៥ ថ្ងៃ! កំពុងបូកលុយ...");
        const userRef = db.collection("users").doc(orderData.seller_id);
        await userRef.set({
            "wallet_balance": admin.firestore.FieldValue.increment(-orderData.seller_earnings),
            "available_balance": admin.firestore.FieldValue.increment(orderData.seller_earnings)
        }, { merge: true });
        await event.data.after.ref.update({ is_settled: true });
    } else {
        console.log("❌ មិនទាន់គ្រប់ ៥ ថ្ងៃ ឬ ទូទាត់រួចហើយ");
    }
});

exports.notifyOnNewChatMessage = onDocumentCreated({
    document: "chats/{chatDocId}",
    region: "asia-southeast1"
}, async (event) => {
    const data = event.data.data();
    const receiverId = data.receiver;
    const senderId = data.sender;
    
    if (!receiverId || senderId === receiverId) {
        console.log("អ្នកផ្ញើ និងអ្នកទទួលជាមនុស្សតែម្នាក់។ មិនផ្ញើ Noti ឡើយ។");
        return null; 
    }
    
    try {
        const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
        const senderName = senderDoc.exists ? (senderDoc.data().name || 'អ្នកប្រើប្រាស់') : 'អ្នកប្រើប្រាស់';
        const userDoc = await admin.firestore().collection("users").doc(receiverId).get();
        if (!userDoc.exists) return null;

        const token = userDoc.data().fcmToken;

        if (token) {
            const messageBody = data.message || "បានផ្ញើសារថ្មី...";
            const message = {
                token: token,
                notification: {
                    title: senderName,
                    body: messageBody,
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "order_channel",
                        icon: 'ic_stat_sesan',
                        color: '#FF4500',
                        sound: "default",
                        clickAction: "FLUTTER_NOTIFICATION_CLICK",
                    }
                },
                data: {
                    type: 'new_chat',
                    chatId: event.params.chatDocId,
                    senderId: String(senderId),
                    senderName: String(senderName),
                    productId: String(data.productId || ''),
                    productName: String(data.productName || ''),
                    sellerId: String(data.seller_id || data.sellerId || ''),
                }
            };

            await admin.messaging().send(message);
            console.log('✅ Chat notification sent to:', receiverId);
        }
    } catch (error) {
        console.error("Error sending chat notification:", error);
    }
    return null;
});

exports.notifyAdminOnNewOrder = onDocumentCreated({
    document: "orders/{orderId}",
    region: "asia-southeast1"
}, async (event) => {
    const orderData = event.data.data();

    if (orderData.status === "pending") {
        try {
            const adminUID = "WBdQVvrgEIPBTcgIlumu6bAZGUl2";
            const adminDoc = await admin.firestore().collection("users").doc(adminUID).get();
            if (adminDoc.exists) {
                const token = adminDoc.data().fcmToken;
                if (token) {
                    const message = {
                        token: token,
                        notification: {
                            title: "📦 Admin មានការកុម្ម៉ង់ថ្មី!",
                            body: "តម្លៃសរុប៖ " + (orderData.total_amount || 0) + "៛",
                        },
                        android: {
                            priority: "high",
                            notification: {
                                channelId: "order_channel",
                                priority: "high",
                                clickAction: "FLUTTER_NOTIFICATION_CLICK",
                            }
                        }
                    };
                    await admin.messaging().send(message);
                    console.log("Notification sent to admin:", adminUID);
                }
            }
        } catch (error) {
            console.error("Error sending admin notification:", error);
        }
    }
    return null;
});

exports.scheduledWalletSettlement = onSchedule({
    schedule: "0 0 * * *", 
    timeZone: "Asia/Phnom_Penh",
    region: "asia-southeast1"
}, async (event) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const fiveDaysAgo = new Date(now.toDate().getTime() - 5 * 24 * 60 * 60 * 1000);
    const fiveDaysAgoTimestamp = admin.firestore.Timestamp.fromDate(fiveDaysAgo);

    const ordersSnapshot = await db.collection("orders")
        .where("is_settled", "==", false)
        .where("packing_date", "<=", fiveDaysAgoTimestamp)
        .get();

    if (ordersSnapshot.empty) return null;

    const batch = db.batch();

    ordersSnapshot.forEach((doc) => {
        const orderData = doc.data();
        const sellerId = orderData.seller_id;
        const earnings = parseFloat(orderData.seller_earnings || 0);

        if (sellerId && earnings > 0) {
            const userRef = db.collection("users").doc(sellerId);
            const orderRef = db.collection("orders").doc(doc.id);

            batch.set(userRef, {
                "wallet_balance": admin.firestore.FieldValue.increment(-earnings),
                "available_balance": admin.firestore.FieldValue.increment(earnings),
            }, { merge: true });

            batch.update(orderRef, {
                "is_settled": true,
                "settled_at": now
            });
        }
    });

    return batch.commit(); 
});

exports.onOrderPackingUpdate = onDocumentUpdated({
    document: "orders/{orderId}",
    region: "asia-southeast1"
}, async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    if (newData.status === 'packing' && oldData.status !== 'packing') {
        const sellerId = newData.seller_id;
        const earnings = parseFloat(newData.seller_earnings || 0);

        if (sellerId && earnings > 0) {
            const userRef = admin.firestore().collection("users").doc(sellerId);
            await userRef.set({
                "today_income": admin.firestore.FieldValue.increment(earnings)
            }, { merge: true });
        }
    }
});

exports.approveSale = onDocumentUpdated({
    document: 'sales/{saleId}',
    region: 'asia-southeast1'
}, async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    if (newData.status === 'completed' && oldData.status !== 'completed') {
        const sellerId = newData.sellerId;
        const amount = newData.amount;

        if (!sellerId || !amount) return null;

        const userRef = admin.firestore().collection('users').doc(sellerId);

        try {
            return await admin.firestore().runTransaction(async (transaction) => {
                const userDoc = await transaction.get(userRef);
                if (!userDoc.exists) return;

                transaction.update(userRef, {
                    wallet_balance: admin.firestore.FieldValue.increment(-amount),
                    available_balance: admin.firestore.FieldValue.increment(amount)
                });
            });
        } catch (error) {
            console.error("Transaction failed: ", error);
        }
    }
    return null;
});

exports.notifyOwnerOnAuctionApproved = onDocumentCreated({
    document: "products/{productId}",
    region: "asia-southeast1"
}, async (event) => {
    const productData = event.data.data();
    if (productData.status !== 'auction') return null;

    const ownerId = productData.owner_id;
    const productName = productData.product_name || 'ទំនិញ';
    const productId = event.params.productId;
    const startPrice = productData.start_price || 0;
    const endTime = productData.end_time;

    if (!ownerId) return null;

    try {
        const userDoc = await admin.firestore().collection("users").doc(ownerId).get();
        if (!userDoc.exists) return null;
        const token = userDoc.data().fcmToken;
        if (!token) return null;

        let endTimeStr = '';
        if (endTime) {
            const endDate = endTime.toDate();
            endTimeStr = `\nបញ្ចប់នៅ៖ ${endDate.getDate()}/${endDate.getMonth() + 1}/${endDate.getFullYear()} ${endDate.getHours()}:${String(endDate.getMinutes()).padStart(2, '0')}`;
        }

        const message = {
            token: token,
            notification: {
                title: "🎉 ការដេញថ្លៃត្រូវបានអនុម័ត!",
                body: `ទំនិញ "${productName}" របស់អ្នកត្រូវបានអនុម័តដោយ Admin។ តម្លៃចាប់ផ្តើម៖ ${startPrice} ៛${endTimeStr}`,
            },
            android: {
                priority: "high",
                notification: {
                    channelId: "high_importance_channel",
                    icon: 'ic_stat_sesan',
                    color: '#FF4500',
                    sound: "default",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                }
            },
            data: {
                productId: productId,
                type: 'auction_approved',
            }
        };

        await admin.messaging().send(message);
        await admin.firestore().collection("users").doc(ownerId).collection("notifications").add({
            title: "ការដេញថ្លៃត្រូវបានអនុម័ត!",
            body: `ទំនិញ "${productName}" ត្រូវបានអនុម័ត`,
            productId: productId,
            type: 'auction_approved',
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return null;
    } catch (error) {
        console.error("Error sending auction approval notification:", error);
        return null;
    }
});

exports.notifyOwnerOnNewBid = onDocumentCreated({
    document: "auction_products/{productId}/bids/{bidId}",
    region: "asia-southeast1"
}, async (event) => {
    const bidData = event.data.data();
    const productId = event.params.productId;

    try {
        const productDoc = await admin.firestore().collection("auction_products").doc(productId).get();
        if (!productDoc.exists) return null;
        const productData = productDoc.data();
        const ownerId = productData.owner_id;
        if (!ownerId || bidData.bidder_id === ownerId) return null;

        const userDoc = await admin.firestore().collection("users").doc(ownerId).get();
        if (!userDoc.exists) return null;
        const token = userDoc.data().fcmToken;
        if (!token) return null;

        const productName = productData.product_name || 'ទំនិញ';
        const bidAmount = bidData.bid_amount || 0;
        const bidderName = bidData.bidder_name || 'អ្នកដេញថ្លៃ';

        const message = {
            token: token,
            notification: {
                title: "💰 មានអ្នកដេញថ្លៃថ្មី!",
                body: bidderName + ' បានដេញថ្លៃ ' + bidAmount + ' ៛ លើ "' + productName + '"',
            },
            android: {
                priority: "high",
                notification: {
                    channelId: "high_importance_channel",
                    icon: 'ic_stat_sesan',
                    color: '#FF4500',
                    sound: "default",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                }
            },
            data: {
                productId: productId,
                type: 'new_bid',
            }
        };

        await admin.messaging().send(message);
        return null;
    } catch (error) {
        console.error('❌ Error:', error);
        return null;
    }
});

exports.notifyOwnerOnAuctionApproved = onDocumentUpdated({
    document: "auction_products/{productId}",
    region: "asia-southeast1"
}, async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const productId = event.params.productId;

    if (beforeData.status !== 'auction' && afterData.status === 'auction') {
        const productName = afterData.product_name || 'ទំនិញ';
        const startPrice = afterData.start_price || 0;
        const ownerId = afterData.owner_id;
        const endTime = afterData.end_time;

        if (!ownerId) return null;

        try {
            const userDoc = await admin.firestore().collection("users").doc(ownerId).get();
            if (userDoc.exists) {
                const token = userDoc.data().fcmToken;
                if (token) {
                    let endTimeStr = '';
                    if (endTime) {
                        const endDate = endTime.toDate();
                        endTimeStr = ' បញ្ចប់នៅ: ' + endDate.getDate() + '/' + (endDate.getMonth() + 1) + '/' + endDate.getFullYear();
                    }
                    await admin.messaging().send({
                        token: token,
                        notification: {
                            title: "🎉 ការដេញថ្លៃត្រូវបានអនុម័ត!",
                            body: 'ទំនិញ "' + productName + '" របស់អ្នកត្រូវបានអនុម័ត។ តម្លៃចាប់ផ្តើម: ' + startPrice + ' ៛' + endTimeStr,
                        },
                        android: {
                            priority: "high",
                            notification: {
                                channelId: "high_importance_channel",
                                icon: 'ic_stat_sesan',
                                color: '#FF4500',
                                sound: "default",
                                clickAction: "FLUTTER_NOTIFICATION_CLICK",
                            }
                        },
                        data: { productId: productId, type: 'auction_approved' }
                    });
                }

                await admin.firestore().collection("users").doc(ownerId).collection("notifications").add({
                    title: "ការដេញថ្លៃត្រូវបានអនុម័ត!",
                    body: 'ទំនិញ "' + productName + '" ត្រូវបានអនុម័ត',
                    productId: productId,
                    type: 'auction_approved',
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }

            let allUsersEndTimeStr = '';
            if (endTime) {
                const endDate = endTime.toDate();
                allUsersEndTimeStr = ' បញ្ចប់នៅ: ' + endDate.getDate() + '/' + (endDate.getMonth() + 1) + '/' + endDate.getFullYear();
            }

            await admin.messaging().send({
                topic: 'all_users',
                notification: {
                    title: "🎉 មានការដេញថ្លៃថ្មី!",
                    body: 'ទំនិញ "' + productName + '" តម្លៃចាប់ផ្តើម ' + startPrice + ' ៛' + allUsersEndTimeStr + ' ចូលដេញថ្លៃឥឡូវនេះ!',
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "high_importance_channel",
                        icon: 'ic_stat_sesan',
                        color: '#FF4500',
                        sound: "default",
                        clickAction: "FLUTTER_NOTIFICATION_CLICK",
                    }
                },
                data: { productId: productId, type: 'auction_approved_all' }
            });
            return null;
        } catch (error) {
            console.error('❌ Error:', error);
            return null;
        }
    }
    return null;
});

exports.productPreview = functions.https.onRequest(async (req, res) => {
    try {
        const parts = req.path.split('/').filter(Boolean);
        const productId = parts.pop();

        if (!productId) return res.status(400).send('Missing product ID');

        const doc = await admin.firestore().collection('products').doc(productId).get();
        if (!doc.exists) return res.status(404).send('Not found');

        const data = doc.data();
        const escapeHtml = (str) => String(str ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');

        const rawImageUrl = (data.image_urls && data.image_urls.length > 0) ? data.image_urls[0] : (data.image_url || '');
        const rawPrice = data.price || 0;
        const cleanPrice = typeof rawPrice === 'string' ? rawPrice.replace(/,/g, '') : rawPrice;
        const numPrice = Number(cleanPrice);
        const formattedPrice = isNaN(numPrice) ? '0' : numPrice.toLocaleString('en-US');
        const productName = escapeHtml(data.product_name || 'ទំនិញ');
        const location = escapeHtml(data.location || '');
        const sellerName = escapeHtml(data.seller_name || data.owner_name || 'មិនស្គាល់');
        const sellerPhone = escapeHtml(data.phone1 || data.seller_phone || '');
        const imageUrl = escapeHtml(rawImageUrl);
        const safeProductId = escapeHtml(productId);

        const html = `<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><meta property="og:title" content="${productName}"><meta property="og:description" content="តម្លៃ៖ ${formattedPrice} ៛"><meta property="og:image" content="${imageUrl}"><meta property="og:url" content="https://sesanshop.com/product/${safeProductId}"><meta property="og:type" content="website"><title>${productName} - Sesan Marketplace</title></head><body><div>${imageUrl ? `<img src="${imageUrl}" alt="${productName}">` : ''}<h1>${productName}</h1><div>${formattedPrice} ៛</div>${location ? `<div>📍 ${location}</div>` : ''}${sellerName ? `<div>👤 ${sellerName} ${sellerPhone ? '| 📞 ' + sellerPhone : ''}</div>` : ''}</div><script>function openApp(){const productId="${safeProductId}";const fallbackUrl="https://sesanshop.com/product/"+productId;const ua=navigator.userAgent;if(/android/i.test(ua)){window.location.href="intent://product/"+productId+"#Intent;scheme=sesanapp;package=com.sesan.app;S.browser_fallback_url="+encodeURIComponent(fallbackUrl)+";end";}else if(/iphone|ipad|ipod/i.test(ua)){const appScheme="sesanapp://product/"+productId;const start=Date.now();window.location.href=appScheme;setTimeout(function(){if(Date.now()-start<2000){window.location.href=fallbackUrl;}},1000);}else{window.location.href=fallbackUrl;}}</script></body></html>`;
        res.set('Cache-Control', 'public, max-age=3600');
        return res.status(200).send(html);
    } catch (e) {
        console.error('productPreview error:', e);
        return res.status(500).send('Error');
    }
});

exports.notifyAdminOnNewAuction = onDocumentCreated({
    document: "auction_products/{productId}",
    region: "asia-southeast1"
}, async (event) => {
    const productData = event.data.data();
    if (productData.status !== 'pending') return null;
    const productName = productData.product_name || 'ទំនិញថ្មី';
    const startPrice = productData.start_price || 0;
    const ownerName = productData.owner_name || 'មិនស្គាល់';
    const productId = event.params.productId;

    try {
        const adminUID = "WBdQVvrgEIPBTcgIlumu6bAZGUl2";
        const adminDoc = await admin.firestore().collection('users').doc(adminUID).get();
        if (!adminDoc.exists) return null;
        const adminToken = adminDoc.data().fcmToken;
        if (!adminToken) return null;

        await admin.messaging().send({
            token: adminToken,
            notification: {
                title: "📢 មានការដេញថ្លៃថ្មីរង់ចាំអនុម័ត!",
                body: '"' + productName + '" ពី ' + ownerName + ' | តម្លៃ: ' + startPrice + ' ៛',
            },
            android: {
                priority: "high",
                notification: {
                    channelId: "order_channel",
                    icon: 'ic_stat_sesan',
                    color: '#FF4500',
                    sound: "default",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                }
            },
            data: { productId: productId, type: 'new_auction_pending' }
        });
        return null;
    } catch (error) {
        console.error('❌ Error:', error);
        return null;
    }
});

exports.notifyAllUsersOnAuctionApproved = onDocumentUpdated({
    document: "auction_products/{productId}",
    region: "asia-southeast1"
}, async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const productId = event.params.productId;

    if (beforeData.status !== 'auction' && afterData.status === 'auction') {
        const productName = afterData.product_name || 'ទំនិញ';
        const startPrice = afterData.start_price || 0;
        const endTime = afterData.end_time;
        const ownerName = afterData.owner_name || 'មិនស្គាល់';

        try {
            let endTimeStr = '';
            if (endTime) {
                const endDate = endTime.toDate();
                endTimeStr = ' | បញ្ចប់: ' + endDate.getDate() + '/' + (endDate.getMonth() + 1) + '/' + endDate.getFullYear();
            }

            await admin.messaging().send({
                topic: 'all_users',
                notification: {
                    title: "🎉 មានការដេញថ្លៃថ្មី!",
                    body: '"' + productName + '" ពី ' + ownerName + ' | តម្លៃចាប់ផ្តើម: ' + startPrice + ' ៛' + endTimeStr + ' | ចូលដេញថ្លៃឥឡូវនេះ!',
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "high_importance_channel",
                        icon: 'ic_stat_sesan',
                        color: '#FF4500',
                        sound: "default",
                        clickAction: "FLUTTER_NOTIFICATION_CLICK",
                    }
                },
                apns: {
                    payload: { aps: { sound: "default", badge: 1 } }
                },
                data: {
                    productId: productId,
                    type: 'auction_started',
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                }
            });

            await admin.firestore().collection("announcements").add({
                title: "ការដេញថ្លៃថ្មី!",
                body: '"' + productName + '" តម្លៃចាប់ផ្តើម ' + startPrice + ' ៛',
                productId: productId,
                type: 'auction_started',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return null;
        } catch (error) {
            console.error('❌ Error sending to all users:', error);
            return null;
        }
    }
    return null;
});

exports.notifyOwnerOnNewComment = onDocumentCreated({
    document: "products/{productId}/comments/{commentId}",
    region: "asia-southeast1"
}, async (event) => {
    const commentData = event.data.data();
    const productId = event.params.productId;
    try {
        const productDoc = await admin.firestore().collection("products").doc(productId).get();
        if (!productDoc.exists) return null;
        const productData = productDoc.data();
        const ownerId = productData.seller_id || productData.owner_id;
        const productName = productData.product_name || 'ទំនិញ';
        const commenterName = commentData.userName || 'អ្នកប្រើប្រាស់';
        const commentText = commentData.content || '';
        if (!ownerId || commentData.userId === ownerId) return null;

        const userDoc = await admin.firestore().collection("users").doc(ownerId).get();
        if (!userDoc.exists) return null;
        const token = userDoc.data().fcmToken;
        if (!token) return null;

        let bodyText = commenterName + ' បានបញ្ចេញមតិ';
        if (commentText) bodyText += ': "' + (commentText.length > 50 ? commentText.substring(0, 50) + '...' : commentText) + '"';
        bodyText += ' លើទំនិញ "' + productName + '"';

        await admin.messaging().send({
            token: token,
            notification: { title: "💬 មានមតិយោបល់ថ្មី!", body: bodyText },
            android: { priority: "high", notification: { channelId: "order_channel", icon: 'ic_stat_sesan', color: '#FF4500', sound: "default", clickAction: "FLUTTER_NOTIFICATION_CLICK" } },
            data: { productId: productId, commentId: event.params.commentId, type: 'new_comment' }
        });

        await admin.firestore().collection("users").doc(ownerId).collection("notifications").add({
            title: "មតិយោបល់ថ្មី", body: bodyText, productId: productId, commentId: event.params.commentId, type: 'new_comment', isRead: false, createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return null;
    } catch (error) {
        console.error('❌ Error:', error);
        return null;
    }
});

exports.notifyOnCommentReply = onDocumentCreated({
    document: "products/{productId}/comments/{commentId}/replies/{replyId}",
    region: "asia-southeast1"
}, async (event) => {
    const replyData = event.data.data();
    const productId = event.params.productId;
    const commentId = event.params.commentId;
    try {
        const commentDoc = await admin.firestore().collection("products").doc(productId).collection("comments").doc(commentId).get();
        if (!commentDoc.exists) return null;
        const commentData = commentDoc.data();
        const commentOwnerId = commentData.userId;
        const replierName = replyData.userName || 'អ្នកប្រើប្រាស់';
        const replyText = replyData.content || '';
        if (!commentOwnerId || replyData.userId === commentOwnerId) return null;

        const userDoc = await admin.firestore().collection("users").doc(commentOwnerId).get();
        if (!userDoc.exists) return null;
        const token = userDoc.data().fcmToken;
        if (!token) return null;

        const productDoc = await admin.firestore().collection("products").doc(productId).get();
        const productName = productDoc.exists ? (productDoc.data().product_name || 'ទំនិញ') : 'ទំនិញ';
        let bodyText = replierName + ' បានឆ្លើយតបមតិរបស់អ្នក';
        if (replyText) bodyText += ': "' + (replyText.length > 50 ? replyText.substring(0, 50) + '...' : replyText) + '"';
        bodyText += ' លើទំនិញ "' + productName + '"';

        await admin.messaging().send({
            token: token,
            notification: { title: "💬 មានការឆ្លើយតបមតិរបស់អ្នក!", body: bodyText },
            android: { priority: "high", notification: { channelId: "order_channel", icon: 'ic_stat_sesan', color: '#FF4500', sound: "default", clickAction: "FLUTTER_NOTIFICATION_CLICK" } },
            data: { productId: productId, commentId: commentId, replyId: event.params.replyId, type: 'comment_reply' }
        });

        await admin.firestore().collection("users").doc(commentOwnerId).collection("notifications").add({
            title: "ការឆ្លើយតបមតិ", body: bodyText, productId: productId, commentId: commentId, replyId: event.params.replyId, type: 'comment_reply', isRead: false, createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return null;
    } catch (error) {
        console.error('❌ Error:', error);
        return null;
    }
});

exports.notifyAdminOnNewVipRequest = onDocumentCreated({
    document: "vip_requests/{requestId}",
    region: "asia-southeast1"
}, async (event) => {
    const requestData = event.data.data();
    const requestId = event.params.requestId;
    const userName = requestData.name || 'មិនស្គាល់';
    const phone = requestData.phone || 'គ្មានលេខ';
    const sesanId = requestData.sesan_id || 'មិនមាន';
    const amount = requestData.amount || 15000;

    try {
        const adminUID = "WBdQVvrgEIPBTcgIlumu6bAZGUl2";
        const adminDoc = await admin.firestore().collection('users').doc(adminUID).get();
        if (!adminDoc.exists) return null;
        const adminToken = adminDoc.data().fcmToken;
        const title = "💎 មានសំណើ VIP ថ្មី!";
        const body = `${userName} (📞 ${phone}) ស្នើសុំ VIP | Sesan ID: ${sesanId} | ទឹកប្រាក់: ${amount} ៛`;

        if (adminToken) {
            await admin.messaging().send({
                token: adminToken,
                notification: { title: title, body: body },
                android: { priority: "high", notification: { channelId: "order_channel", icon: 'ic_stat_sesan', color: '#FF4500', sound: "default", clickAction: "FLUTTER_NOTIFICATION_CLICK" } },
                data: { requestId: requestId, type: 'vip_request' }
            });
        }

        await admin.firestore().collection("users").doc(adminUID).collection("notifications").add({
            title: title, body: body, requestId: requestId, type: 'vip_request', isRead: false, createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return null;
    } catch (error) {
        console.error('❌ Error sending VIP request notification:', error);
        return null;
    }
});

exports.notifyAdminOnNewShopUpgrade = onDocumentCreated({
    document: "shop_upgrade_requests/{requestId}",
    region: "asia-southeast1"
}, async (event) => {
    const requestData = event.data.data();
    const requestId = event.params.requestId;
    const userName = requestData.name || 'មិនស្គាល់';
    const phone = requestData.phone || 'គ្មានលេខ';
    const sesanId = requestData.sesan_id || 'មិនមាន';
    const tier = requestData.tier || 'basic';
    const price = requestData.price || 0;
    const shopName = requestData.shop_name || '';

    try {
        const adminUID = "WBdQVvrgEIPBTcgIlumu6bAZGUl2";
        const adminDoc = await admin.firestore().collection('users').doc(adminUID).get();
        if (!adminDoc.exists) return null;
        const adminToken = adminDoc.data().fcmToken;
        const title = "🏪 មានសំណើដំឡើងហាងថ្មី!";
        let body = `${userName} (📞 ${phone}) ស្នើរដំឡើងហាងជា ${tier === 'premium' ? 'Premium' : 'Basic'} | ទឹកប្រាក់: ${price} ៛`;
        if (sesanId !== 'មិនមាន') body += `| Sesan ID: ${sesanId}`;
        if (shopName) body += `| ឈ្មោះហាង: ${shopName}`;

        if (adminToken) {
            await admin.messaging().send({
                token: adminToken,
                notification: { title: title, body: body },
                android: { priority: "high", notification: { channelId: "order_channel", icon: 'ic_stat_sesan', color: '#FF4500', sound: "default", clickAction: "FLUTTER_NOTIFICATION_CLICK" } },
                data: { requestId: requestId, type: 'shop_upgrade_request' }
            });
        }

        await admin.firestore().collection("users").doc(adminUID).collection("notifications").add({
            title: title, body: body, requestId: requestId, type: 'shop_upgrade_request', isRead: false, createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return null;
    } catch (error) {
        console.error('❌ Error sending shop upgrade request notification:', error);
        return null;
    }
});

exports.notifyOwnerOnNewRating = onDocumentUpdated({
    document: "products/{productId}",
    region: "asia-southeast1"
}, async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const productId = event.params.productId;
    const beforeReviews = beforeData.totalReviews || 0;
    const afterReviews = afterData.totalReviews || 0;
    if (afterReviews <= beforeReviews) return null;

    const ownerId = afterData.seller_id;
    if (!ownerId) return null;
    const productName = afterData.product_name || 'ទំនិញ';
    const avgRating = afterData.avgRating || 0;

    try {
        await admin.firestore().collection("users").doc(ownerId).collection("notifications").add({
            title: "⭐ មានការវាយតម្លៃថ្មី",
            body: `ផលិតផល "${productName}" ទទួលបានពិន្ទុថ្មី ${avgRating} ផ្កាយ`,
            productId: productId,
            type: 'new_rating',
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
        if (ownerDoc.exists) {
            const token = ownerDoc.data().fcmToken;
            if (token) {
                await admin.messaging().send({
                    token: token,
                    notification: { title: "⭐ មានការវាយតម្លៃថ្មី", body: `ទំនិញ "${productName}" ទទួលបាន ${avgRating} ផ្កាយ` },
                    android: { priority: "high", notification: { channelId: "order_channel", icon: 'ic_stat_sesan', color: '#FF4500', sound: "default", clickAction: "FLUTTER_NOTIFICATION_CLICK" } },
                    data: { productId: productId, type: 'new_rating' }
                });
            }
        }
        return null;
    } catch (error) {
        console.error('❌ Error sending rating notification:', error);
        return null;
    }
});

exports.autoAddShopTierToProduct = onDocumentCreated({
    document: "products/{productId}",
    region: "asia-southeast1"
}, async (event) => {
    const productData = event.data.data();
    const sellerId = productData.seller_id;
    if (!sellerId) return null;

    try {
        const userDoc = await admin.firestore().collection('users').doc(sellerId).get();
        const shopTier = userDoc.exists ? userDoc.data()?.shop_tier : null;
        if (shopTier) await event.data.ref.update({ shop_tier: shopTier });
    } catch (e) {
        console.error('❌ Error auto-setting shop_tier:', e);
    }
    return null;
});

exports.updateProductsShopTierOnUserTierChange = onDocumentUpdated({
    document: "users/{userId}",
    region: "asia-southeast1"
}, async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const oldTier = beforeData.shop_tier;
    const newTier = afterData.shop_tier;
    if (oldTier === newTier) return null;

    const sellerId = event.params.userId;
    try {
        const productsSnap = await admin.firestore().collection('products').where('seller_id', '==', sellerId).get();
        if (productsSnap.empty) return null;
        const batch = admin.firestore().batch();
        productsSnap.forEach(doc => {
            batch.update(doc.ref, { shop_tier: newTier || admin.firestore.FieldValue.delete() });
        });
        await batch.commit();
    } catch (e) {
        console.error('❌ Error updating products shop_tier:', e);
    }
    return null;
});

exports.updateSellerInfoOnProducts = onDocumentUpdated({
    document: "users/{userId}",
    region: "asia-southeast1"
}, async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const sellerId = event.params.userId;
    const oldName = beforeData.name || beforeData.fullName || beforeData.displayName || '';
    const newName = afterData.name || afterData.fullName || afterData.displayName || '';
    const oldPhoto = beforeData.photoUrl || beforeData.avatar || beforeData.profilePic || '';
    const newPhoto = afterData.photoUrl || afterData.avatar || afterData.profilePic || '';
    if (oldName === newName && oldPhoto === newPhoto) return null;

    try {
        const productsSnap = await admin.firestore().collection('products').where('seller_id', '==', sellerId).get();
        if (productsSnap.empty) return null;
        const batch = admin.firestore().batch();
        let updateCount = 0;
        productsSnap.forEach(doc => {
            const updates = {};
            if (oldName !== newName && newName) updates.seller_name = newName;
            if (oldPhoto !== newPhoto && newPhoto) updates.seller_photo = newPhoto;
            if (Object.keys(updates).length > 0) {
                batch.update(doc.ref, updates);
                updateCount++;
            }
        });
        if (updateCount > 0) await batch.commit();
        return null;
    } catch (error) {
        console.error(`❌ Error updating seller info on products:`, error);
        return null;
    }
});

exports.addBlockedUsersField = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'សូម Login ជាមុនសិន!');
    }

    const adminUid = "WBdQVvrgEIPBTcgIlumu6bAZGUl2";
    if (context.auth.uid !== adminUid) {
        throw new functions.https.HttpsError('permission-denied', 'មានតែ Admin ទេដែលអាចហៅមុខងារនេះ!');
    }

    try {
        const usersSnapshot = await admin.firestore().collection('users').get();
        const batch = admin.firestore().batch();
        let count = 0;

        usersSnapshot.forEach((doc) => {
            const data = doc.data();
            if (!data.hasOwnProperty('blockedUsers')) {
                batch.update(doc.ref, { blockedUsers: [] });
                count++;
            }
        });

        if (count > 0) {
            await batch.commit();
            return { success: true, updated: count, message: `បានបន្ថែម blockedUsers ដល់ ${count} User` };
        } else {
            return { success: true, updated: 0, message: 'User ទាំងអស់មាន field blockedUsers រួចហើយ' };
        }
    } catch (error) {
        console.error("Error updating users:", error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

async function anonymizeExpiredUserHistory(db, uid) {
    const deletedName = "Deleted user";
    const chatSnapshot = await db.collection("chats").where("users", "array-contains", uid).get();
    const chatWriter = db.bulkWriter();
    for (const chatDoc of chatSnapshot.docs) {
        const data = chatDoc.data();
        const update = { deletedUsers: admin.firestore.FieldValue.arrayUnion(uid) };
        if (data.sender === uid) {
            update.sender_name = deletedName;
            update.senderName = deletedName;
        }
        if (data.receiver === uid) {
            update.receiver_name = deletedName;
            update.receiverName = deletedName;
        }
        chatWriter.update(chatDoc.ref, update);
    }
    await chatWriter.close();

    const orderQueries = [
        ["customer_id", uid, "buyer"],
        ["customerId", uid, "buyer"],
        ["seller_id", uid, "seller"],
        ["sellerId", uid, "seller"]
    ];

    const handledOrderIds = new Set();
    const orderWriter = db.bulkWriter();

    for (const [field, value, role] of orderQueries) {
        const snapshot = await db.collection("orders").where(field, "==", value).get();

        for (const orderDoc of snapshot.docs) {
            const key = `${orderDoc.id}:${role}`;
            if (handledOrderIds.has(key)) continue;
            handledOrderIds.add(key);

            const data = orderDoc.data();
            const update = { deletedUsers: admin.firestore.FieldValue.arrayUnion(uid) };

            if (role === "buyer") {
                update.customer_name = deletedName;
                update.customerName = deletedName;
                update.buyer_name = deletedName;
                update.buyerName = deletedName;
                update.phone_number = "";
                update.customer_phone = "";
                update.buyer_phone = "";
                update.shipping_address = "";
                update.buyer_address = "";
            } else {
                update.seller_name = deletedName;
                update.sellerName = deletedName;
                update.seller_phone = "";
                update.seller_photo = "";

                if (Array.isArray(data.items)) {
                    update.items = data.items.map((item) => {
                        if (!item || typeof item !== "object") return item;
                        const itemSellerId = String(item.seller_id || item.sellerId || "");
                        if (itemSellerId !== uid) return item;
                        return {
                            ...item,
                            seller_name: deletedName,
                            sellerName: deletedName,
                            seller_phone: "",
                            seller_photo: ""
                        };
                    });
                }
            }

            orderWriter.update(orderDoc.ref, update);
        }
    }
    await orderWriter.close();
}

exports.cleanupExpiredDeletedAccounts = onSchedule({
    schedule: "every 60 minutes",
    timeZone: "Asia/Phnom_Penh",
    region: "asia-southeast1",
    timeoutSeconds: 540,
    memory: "512MiB",
    maxInstances: 1
}, async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const recoverableSnapshot = await db.collection("deleted_accounts")
        .where("status", "==", "recoverable")
        .get();

    const expiredDocs = recoverableSnapshot.docs
        .filter((doc) => {
            const deadline = doc.data().restoreDeadline;
            return deadline && typeof deadline.toMillis === "function" && deadline.toMillis() <= now.toMillis();
        })
        .sort((a, b) => a.data().restoreDeadline.toMillis() - b.data().restoreDeadline.toMillis())
        .slice(0, 100);

    if (expiredDocs.length === 0) {
        console.log("No expired account archives found.");
        return null;
    }

    let deletedCount = 0;
    let failedCount = 0;

    for (const archiveDoc of expiredDocs) {
        const uid = archiveDoc.id;

        try {
            const claimed = await db.runTransaction(async (transaction) => {
                const freshArchive = await transaction.get(archiveDoc.ref);
                if (!freshArchive.exists) return false;

                const data = freshArchive.data();
                const deadline = data.restoreDeadline;
                const isExpired = deadline && typeof deadline.toMillis === "function" && deadline.toMillis() <= now.toMillis();

                if (data.status !== "recoverable" || !isExpired) return false;

                transaction.update(archiveDoc.ref, {
                    status: "deleting",
                    deletionStartedAt: admin.firestore.FieldValue.serverTimestamp()
                });
                return true;
            });

            if (!claimed) continue;

            await anonymizeExpiredUserHistory(db, uid);
            await db.collection("users").doc(uid).delete();
            try {
                await admin.auth().deleteUser(uid);
            } catch (authError) {
                if (authError.code !== "auth/user-not-found") throw authError;
            }

            await db.recursiveDelete(archiveDoc.ref);
            deletedCount++;
            console.log(`Permanently deleted expired account: ${uid}`);
        } catch (error) {
            failedCount++;
            console.error(`Failed to delete expired account ${uid}:`, error);

            try {
                await archiveDoc.ref.set({
                    status: "recoverable",
                    cleanupError: String(error && error.message ? error.message : error),
                    cleanupLastAttemptAt: admin.firestore.FieldValue.serverTimestamp()
                }, {merge: true});
            } catch (retryError) {
                console.error(`Could not reset cleanup status for ${uid}:`, retryError);
            }
        }
    }

    console.log(`Expired account cleanup finished. Deleted: ${deletedCount}, failed: ${failedCount}`);
    return null;
});
