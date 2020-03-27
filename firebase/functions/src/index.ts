import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as sgMail from '@sendgrid/mail';
import * as otpGenerator from 'otp-generator';

admin.initializeApp();
sgMail.setApiKey(functions.config().sendgrid.key);

export const sendPasscode = functions.https.onCall(async (data, context) => {
    const db = admin.firestore();
    const isApproved = !(await db.collection("ApprovedUsers").where('users', 'array-contains', data.email).get()).empty;

    if (!isApproved) {
        throw new functions.https.HttpsError('failed-precondition', "This user is not on the approved list of users.");
    }

    const timestamp = `${new Date().toDateString()} at ${new Date().toTimeString()}`;
    const passcode = otpGenerator.generate(6, {upperCase: false, specialChars: false});

    // tslint:disable-next-line:no-floating-promises
    await sgMail.send({
        to: data.email,
        from: 'bizboard@eshansingh.com',
        templateId: 'd-d92f3ab7837c4ab28d60892a36193cab',
        dynamicTemplateData: { timestamp, passcode }
    });

    await db.collection("Verifications").doc(data.email).set({ passcode });
});

export const verifyPasscode = functions.https.onCall(async (data, context) => {
    const db = admin.firestore();

    try {
        const userVerification = await db.collection("Verifications").doc(data.email).get();

        if (userVerification.exists) {
            const passcode = userVerification?.data()?.passcode;

            if (passcode === data.passcode) {
                const token = await admin.auth().createCustomToken(data.email);
                // tslint:disable-next-line:no-floating-promises
                db.collection("Verifications").doc(data.email).delete();

                return { token };
            } else {
                return { token: null };
            }
        } else {
            throw new functions.https.HttpsError('not-found', "A passcode was never generated for this user");
        }
    } catch(err) {
        console.log("Error retrieving documents", err);
        throw new functions.https.HttpsError('unknown', "Error retriving document");
    }
});
