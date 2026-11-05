# Sync between MeTube Super and MeTube Ember

Sync keeps your **tags, favourites, playlists, resume positions and
transcripts** the same on your phone (MeTube Super) and your computer
(MeTube Ember). It is optional and off until you choose a folder.

The apps never talk to each other or to any service. Each one writes a small
file into a folder you choose and reads the files of your other devices from
that folder. Copying the folder between the devices is done by a sync program
you pick: Syncthing at home, or the cloud drive you already use.

- **It is not a backup.** Something deleted on one device is deleted on the
  others. Keep using the backups in Settings.
- **MeTube Lite does not sync.**
- **The clips themselves do not travel.** They stay on your server; only what
  you did with them does.

## Option A: at home, with Syncthing (no cloud)

The files go straight from the phone to the computer over your own network.

**On the computer**

1. Install [Syncthing](https://syncthing.net/downloads/) (SyncTrayzor or the
   official Windows build both work) and open its page.
2. Make an empty folder, for example `Documents\MeTube Sync`, and add it in
   Syncthing as a shared folder.

**On the phone**

3. Install **Syncthing-Fork** from [F-Droid](https://f-droid.org/packages/com.github.catfriend1.syncthingandroid/).
4. Add the computer as a device (scan the QR code that Syncthing shows on the
   computer under *Actions → Show ID*), then accept the folder it offers and
   put it in a new folder on the phone, for example `MeTube Sync`.
5. In Syncthing-Fork's settings, choose **Run conditions → Wi-Fi only**, so it
   spares the battery and your mobile data.
6. Let Syncthing-Fork run in the background: Android *Settings → Apps →
   Syncthing-Fork → Battery → Unrestricted*. On Samsung phones also remove it
   from *Sleeping apps*. A phone that puts it to sleep is the usual reason
   sync stops.

**In the apps**

7. **MeTube Super:** *Settings → Sync with the computer → Choose a folder*,
   pick the phone's `MeTube Sync` folder in the system picker, and allow it.
8. **MeTube Ember:** *Settings → Sync → Choose a folder*, and pick
   `Documents\MeTube Sync`.

After the first round each app lists the other device by name. Changes travel
the next time both are on the home network.

## Option B: through a cloud drive

Use this when the phone and the computer are rarely on the same network.

1. **On the computer:** make a folder inside your cloud drive's folder
   (OneDrive, Google Drive or Dropbox), for example `OneDrive\MeTube Sync`, and
   choose it in **MeTube Ember** under *Settings → Sync*.
2. **On the phone:** install **FolderSync**, connect it to the same cloud
   account, and make a **two-way** sync between that cloud folder and a folder
   on the phone, with a schedule (every hour is plenty).
3. In **MeTube Super**, choose the phone's folder under *Settings → Sync with
   the computer*.

The cloud's own phone app is not enough: it shows the files but does not keep
a real folder on the phone that another app can read.

## When something looks wrong

- **"Nothing has come from it for over two days"** beside a device: the sync
  program is paused or asleep on one side. Open it and check that it is
  running and allowed in the background.
- **"The sync folder could not be read"**: the folder moved, its drive is
  missing, or the phone took back the permission. Choose the folder again.
- **A phone or computer you no longer use:** *Forget this device* on its row.
  Its transcripts move to this device's folder first, so none is lost.
- **Turning sync off** stops reading and writing; the folder is left as it is.

---

## بالعربية (ملخص)

المزامنة تجعل **الوسوم والمفضلة والقوائم ومواضع التوقف والنصوص** نفسها في
MeTube Super على الجوال وMeTube Ember على الحاسوب. اختيارية ومطفأة حتى تختار
مجلداً، والتطبيقان لا يرسلان شيئاً إلى أي خدمة: كلٌّ منهما يكتب ملفاً صغيراً في
مجلد تختاره، وبرنامج مزامنة تختاره أنت ينقل المجلد بين الجهازين. **ليست نسخة
احتياطية**، وLite لا يزامن، والمقاطع نفسها تبقى على السيرفر.

**داخل البيت (Syncthing):**
1. على الحاسوب: ثبّت Syncthing، وأنشئ مجلداً فارغاً مثل `Documents\MeTube Sync`
   وشاركه فيه.
2. على الجوال: ثبّت **Syncthing-Fork** من F-Droid، وأضف الحاسوب جهازاً، واقبل
   المجلد في مجلد جديد على الجوال.
3. اضبط Syncthing-Fork على **Wi-Fi فقط**، واسمح له بالعمل في الخلفية بلا قيود
   بطارية (وفي سامسونج أخرجه من «التطبيقات النائمة»).
4. في **Super**: «الإعدادات ← المزامنة مع الكمبيوتر ← اختر مجلداً» واختر مجلد
   الجوال. وفي **Ember**: «الإعدادات ← المزامنة ← اختر مجلداً» واختر مجلد الحاسوب.

**عبر السحابة:** مجلد داخل OneDrive أو Google Drive أو Dropbox على الحاسوب تختاره
في Ember، وعلى الجوال **FolderSync** بمزامنة في الاتجاهين بين ذلك المجلد السحابي
ومجلد على الجوال تختاره في Super.

**إن ظهر «لم يصل منه شيء منذ أكثر من يومين»** فبرنامج المزامنة متوقف أو نائم في
أحد الجهازين. **وإن ظهر «تعذّرت قراءة مجلد المزامنة»** فاختر المجلد من جديد.
