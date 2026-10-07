# Google Apps Script OTP setup for MS Defence Academy

यह setup password reset OTP को Gmail से भेजता है। OTP app या Google Sheet में save नहीं होता; backend केवल उसका bcrypt hash MongoDB में रखता है और 10 मिनट बाद OTP expire हो जाता है।

## 1. Google Apps Script website खोलें

1. Browser में **https://script.google.com/** खोलें।
2. अपने academy Gmail से sign in करें।
3. **New project** पर click करें।
4. Project का नाम रखें: `MS Defence Academy OTP Mailer`।
5. `Code.gs` में नीचे दिया पूरा code paste करें।
6. `SCRIPT_SECRET` की value बदलें। यह वही secret Render में `GOOGLE_OTP_SCRIPT_SECRET` के रूप में रखना है।
7. Save करें।

## 2. Code.gs में यह code डालें

```javascript
const SCRIPT_SECRET = 'CHANGE_THIS_TO_A_LONG_RANDOM_SECRET';

function json(value) {
  return ContentService
    .createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    const data = JSON.parse((e.postData && e.postData.contents) || '{}');
    if (data.secret !== SCRIPT_SECRET) {
      return json({ ok: false, error: 'Unauthorized' });
    }
    if (data.action !== 'send_otp' || !data.to || !/^\d{6}$/.test(String(data.otp))) {
      return json({ ok: false, error: 'Invalid request' });
    }

    const name = String(data.name || 'Academy user');
    const otp = String(data.otp);
    const minutes = Number(data.expiresInMinutes || 10);
    const subject = 'MS Defence Academy password reset OTP';
    const text =
      'Hello ' + name + ',\n\n' +
      'Your MS Defence Academy password reset OTP is: ' + otp + '\n\n' +
      'This OTP expires in ' + minutes + ' minutes. Do not share it with anyone.\n\n' +
      'If you did not request this, please ignore this email.';
    const html =
      '<div style="font-family:Arial,sans-serif;max-width:520px">' +
      '<h2 style="color:#07533f">MS Defence Academy</h2>' +
      '<p>Hello ' + escapeHtml(name) + ',</p>' +
      '<p>Your password reset OTP is:</p>' +
      '<div style="font-size:30px;font-weight:bold;letter-spacing:8px;color:#07533f">' + otp + '</div>' +
      '<p>This OTP expires in <b>' + minutes + ' minutes</b>. Do not share it with anyone.</p>' +
      '<p>If you did not request this, please ignore this email.</p></div>';

    GmailApp.sendEmail(data.to, subject, text, {
      htmlBody: html,
      name: 'MS Defence Academy',
    });
    return json({ ok: true });
  } catch (error) {
    return json({ ok: false, error: String(error && error.message || error) });
  }
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, function (character) {
    return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' })[character];
  });
}
```

## 3. Script deploy करें

1. ऊपर दाईं तरफ **Deploy** → **New deployment** चुनें।
2. Type में **Web app** चुनें।
3. **Execute as:** `Me` चुनें।
4. **Who has access:** `Anyone` चुनें।
5. **Deploy** दबाएँ।
6. Google permission मांगे तो academy Gmail से **Authorize access** करें। अगर “unverified app” दिखे तो **Advanced** → **Go to MS Defence Academy OTP Mailer** → **Allow** चुनें।
7. जो **Web app URL** मिले, उसे copy करें। यह `https://script.google.com/macros/s/.../exec` जैसा होगा। यही Render में `GOOGLE_OTP_SCRIPT_URL` की value है।

> Code बदलने के बाद हमेशा **Deploy → Manage deployments → Edit → New version → Deploy** करें। URL वही रह सकता है, लेकिन नया version deploy करना जरूरी है।

## 4. Render में कौन से names डालने हैं

Render dashboard खोलें → आपका backend Web Service → **Environment** → **Add Environment Variable**:

| Name | Value |
|---|---|
| `GOOGLE_OTP_SCRIPT_URL` | Apps Script का `/exec` Web app URL |
| `GOOGLE_OTP_SCRIPT_SECRET` | Code.gs में `SCRIPT_SECRET` के समान वही long random value |

फिर **Save Changes** करें। Render नया deploy करेगा। URL में `/exec` होना चाहिए; `/dev` URL production में नहीं लगाना है।

## 5. Password reset का flow

1. Login page पर **Forgot password?** दबाएँ।
2. Registered admin या student email डालें।
3. Backend user खोजकर 6-digit OTP बनाता है।
4. OTP Google Apps Script → Gmail से registered email पर जाता है।
5. OTP MongoDB में hash होकर store होता है; plain OTP store नहीं होता।
6. 10 मिनट और अधिकतम 5 गलत attempts के बाद OTP invalid हो जाता है।
7. User नया password बनाता है। यह student और admin दोनों के लिए काम करता है।

## 6. Security log

Admin → More → **Security logs** में दिखेगा:

- login successful / failed
- password reset requested / completed
- registered email/name
- student या admin role
- IP address
- date और local time

Security logs admin-only API से आते हैं। OTP, password और password hash कभी log नहीं होते।

## 7. QR entry/exit

Admin → Scan Attendance में:

- पहली scan पर student data के साथ **Mark entry** दिखेगा।
- Entry save होने के बाद उसी दिन उसी QR पर **Mark exit** दिखेगा।
- Exit के बाद button disabled हो जाएगा और Entry/Exit दोनों timing दिखेंगी।
- Database Attendance record में `entryAt` और `exitAt` fields save होंगे।
- Existing attendance history में भी Entry और Exit time दिखेंगे।
- एक admin के scanner से उसी scanned student का data ही इस्तेमाल होगा; scanner duplicate open-entry नहीं बनाएगा।

## Important

Gmail sending quota Google account पर लागू होता है। OTP email न आए तो Apps Script **Executions** में error देखें और Render logs में `OTP email service` error देखें।
