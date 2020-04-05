// tslint:disable:no-floating-promises
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();
let isSendGridInit = false;

export const updateBookingsData = functions.runWith({timeoutSeconds: 300, memory: '512MB'})
    .storage.bucket('bizboard-bookings').object().onFinalize(async (object) => {
    const path = await import('path');

    if (!object.name || (path.extname(object.name) !== '.xls' && path.extname(object.name) !== '.xlsx')) {
        return;
    }

    const os = await import('os');

    const dataTempLocation = path.join(os.tmpdir(), object.name);
    await admin.storage().bucket(object.bucket).file(object.name).download({destination: dataTempLocation});

    const XLSX = await import('xlsx');

    const workbook = XLSX.readFile(dataTempLocation, {cellDates: true});
    const jsonStream = XLSX.stream.to_json(workbook.Sheets[workbook.SheetNames[0]], {raw: false});

    const moment = await import('moment');

    const db = admin.firestore();
    let total = 0;
    let totalSold = 0;
    for await (const row of jsonStream) {
        const valueWt = parseFloat(row['Auto Wt']);
        total += valueWt;
        if (row['Stage'] === 'S') {
            totalSold += valueWt;
        }

        db.collection('Bookings').doc(row['Internal ID']).set({
            year: row['Year'],
            accName: row['Account Name'],
            oppName: row['Opportunity Name'],
            pgi: row['PGI'],
            valueUnWt: parseFloat(row['Auto UnWt']),
            valueWt,
            stage: row['Stage'],
            cttSignDate: moment.utc(row['CTT Sign Date'], 'DD/MM/YYYY').toDate(),
            salesStageDate: moment.utc(row['Sales Stage Date'], 'DD/MM/YYYY').toDate(),
            month: row['Month'],
            quarter: row['Quarter'],
            segment: row['Segment'],
            subSegment: row['Sub-Segment'],
            sector: row['Sector'],
            country: row['Country']
        });
    }

    const target = (await db.collection("Constants").doc("bookings").get()).data()?.target;
    const soldPercent = (totalSold / target) * 100;

    db.collection("Overall").doc("bookings").set({total, totalSold, soldPercent});
});

export const updateProposalsData = functions.runWith({timeoutSeconds: 300, memory: '512MB'})
    .storage.bucket('bizboard-proposals').object().onFinalize(async (object) => {
    const path = await import('path');

    if (!object.name || (path.extname(object.name) !== '.xls' && path.extname(object.name) !== '.xlsx')) {
        return;
    }

    const os = await import('os');

    const dataTempLocation = path.join(os.tmpdir(), object.name);
    await admin.storage().bucket(object.bucket).file(object.name).download({destination: dataTempLocation});

    const XLSX = await import('xlsx');

    const workbook = XLSX.readFile(dataTempLocation, {cellDates: true});
    const jsonStream = XLSX.stream.to_json(workbook.Sheets[workbook.SheetNames[0]], {raw: false});

    const moment = await import('moment');

    const db = admin.firestore();
    let total = 0;
    let totalWon = 0;
    let totalLost = 0;
    let totalInProgress = 0;
    let totalCompleted = 0;
    for await (const row of jsonStream) {
        total += 1;
        switch (row['Stage']) {
            case "In Progress":
                totalInProgress += 1;
                break;
            case "Won":
                totalWon += 1;
            case "Lost":
                totalLost += 1;
            case "Submitted":
                totalCompleted += 1;
                break;
        }

        db.collection('Proposals').doc(row['Thor ID']).set({
            apnId: row['APN ID'],
            accName: row['Account Name'],
            oppName: row['Opportunity Name'],
            value: parseFloat(row['Value']),
            coeLead: row['COE Lead'],
            stage: row['Stage'],
            targetQuarter: row['Target Quarter'],
            segment: row['Segment'],
            startDate: moment.utc(row['Start Date'], 'DD-MMM-YYYY').toDate(),
            endDate: moment.utc(row['End Date'], 'DD-MMM-YYYY').toDate(),
        });
    }

    const wonPercent = (totalWon / (totalWon + totalLost)) * 100;

    db.collection("Overall").doc("proposals").set({ wonPercent, totalInProgress, totalCompleted, total});
});

export const sendPasscode = functions.https.onCall(async (data, context) => {
    const sgMail = await import('@sendgrid/mail');

    if (!isSendGridInit) {
        sgMail.setApiKey(functions.config().sendgrid.key);
        isSendGridInit = true;
    }

    const db = admin.firestore();
    const isApproved = !(await db.collection("Constants").where('userEmails', 'array-contains', data.email).get()).empty;

    if (!isApproved) {
        throw new functions.https.HttpsError('failed-precondition', "This user is not approved.");
    }

    const otpGenerator = await import('otp-generator');

    const timestamp = `${new Date().toDateString()} at ${new Date().toTimeString()}`;
    const passcode = otpGenerator.generate(6, {upperCase: false, specialChars: false});

    await sgMail.send({
        to: data.email,
        from: 'noreply@bytecake.com',
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
                db.collection("Verifications").doc(data.email).delete();

                return { token };
            } else {
                return { token: null };
            }
        } else {
            throw new functions.https.HttpsError('not-found', "A passcode was never generated for this user");
        }
    } catch(err) {
        throw new functions.https.HttpsError('unknown', "Error retriving document");
    }
});
