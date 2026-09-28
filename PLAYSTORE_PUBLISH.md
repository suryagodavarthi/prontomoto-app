# Play Store Publishing Guide — ProntoMoto App

---

## 1. Create a Google Play Developer Account
- Go to [play.google.com/console](https://play.google.com/console)
- Pay the **$25 one-time registration fee**
- Fill in your developer profile

---

## 2. Prepare the App

### Update `pubspec.yaml` — set version
```yaml
version: 1.0.0+1   # format: versionName+versionCode
```

### Update `android/app/build.gradle`
```gradle
android {
    defaultConfig {
        applicationId "com.yourcompany.prontomoto"  // unique ID
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
}
```

### Update app name in `android/app/src/main/AndroidManifest.xml`
```xml
<application android:label="ProntoMoto" ...>
```

---

## 3. Generate a Keystore (Sign the App)

Run this **once** and keep the `.jks` file safe forever:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

### Create `android/key.properties`
```properties
storePassword=<your-password>
keyPassword=<your-password>
keyAlias=upload
storeFile=C:/Users/ASUS/upload-keystore.jks
```

### Update `android/app/build.gradle` to use keystore
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
keystoreProperties.load(new FileInputStream(keystorePropertiesFile))

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

> WARNING: Add `key.properties` and `*.jks` to `.gitignore` — never commit these!

---

## 4. Build the Release App

**Recommended — App Bundle (AAB):**
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

---

## 5. Add App to Play Console

1. Go to Play Console → **Create app**
2. Fill in: App name, Default language, App/Game, Free/Paid
3. Complete all **policy declarations**

---

## 6. Set Up the Store Listing

Go to **Store presence → Main store listing** and fill:
- App name, short description, full description
- **Screenshots** (phone, 7" tablet, 10" tablet)
- **App icon** (512×512 PNG)
- **Feature graphic** (1024×500 PNG)

---

## 7. Upload the AAB

1. Go to **Production → Create new release**
2. Upload the `.aab` file
3. Add release notes (what's new)
4. **Review and roll out**

---

## 8. Complete Required Sections

Play Console will block publish until these are done:
- **App content** → Privacy policy URL, ads declaration, target audience
- **Content rating** → Fill the questionnaire
- **Target countries** → Select where to distribute
- **Pricing** → Free or paid

---

## Quick Checklist

- [ ] Developer account created ($25)
- [ ] `applicationId` is unique (e.g. `com.prontomoto.app`)
- [ ] Keystore generated & backed up safely
- [ ] `key.properties` added to `.gitignore`
- [ ] `flutter build appbundle --release` succeeds
- [ ] Store listing complete (icon, screenshots, description)
- [ ] Privacy policy URL ready
- [ ] Content rating questionnaire done

---

> First time review by Google usually takes 3-7 days.
> After that, updates are reviewed in a few hours.
