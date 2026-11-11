# Social App

Flutter social media app UI (home, messages, notifications, profile) built with GitHub Actions.

## Termux setup
pkg update && pkg install -y git unzip
unzip social_app.zip -d ~/social_app
cd ~/social_app
git init && git add . && git commit -m "init"
git branch -M main
git remote add origin https://github.com/YOUR_USER/social_app.git
git push -u origin main

Then open the Actions tab on GitHub. The "Build Android APK" workflow produces
the APK in the run's Artifacts section.
