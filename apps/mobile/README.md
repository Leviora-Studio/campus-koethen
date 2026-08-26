# Campus Köthen

Campus Köthen — an independent, unofficial campus app.

## Branding

The binding logo sources live in `assets/branding/`. Platform launcher, splash
and web icons are generated from the icon source with:

```sh
swift tool/generate_brand_assets.swift
```

Do not replace individual generated size variants. The visible product name is
always `Campus Köthen`; `campus_koethen` remains only the internal Dart package
name.

## Android release signing

Android release artefacts are never signed with Flutter's public debug key. Inject all four
values through the local environment or the CI secret store before building a distributable
release:

- `CAMPUS_ANDROID_KEYSTORE_PATH`: path to the private keystore
- `CAMPUS_ANDROID_KEYSTORE_PASSWORD`: keystore password
- `CAMPUS_ANDROID_KEY_ALIAS`: release-key alias
- `CAMPUS_ANDROID_KEY_PASSWORD`: release-key password

Then build with `flutter build appbundle --release`. A partial configuration fails during Gradle
configuration. With none of the variables set, Gradle leaves the release artefact unsigned; this
is suitable for local compilation checks only and cannot be published as the official app. Never
commit the keystore or its credentials.
