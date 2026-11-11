# Swifly

Flutter social media app (home feed, messages, notifications, profile) built with GitHub Actions.

## Termux setup
pkg update && pkg install -y git unzip
unzip swifly.zip -d ~/swifly
cd ~/swifly
git init && git add . && git commit -m "init"
git branch -M main
git remote add origin https://github.com/YOUR_USER/swifly.git
git push -u origin main

Then open the Actions tab on GitHub. The "Build Android APK" workflow produces
the APK in the run's Artifacts section.

## Notifications

- Red unread count on the bell icon (Notifications tab).
- Popup card at the top when a new notification arrives. Tap it to open, swipe up to dismiss.
- Tapping a like, save, comment or reply opens the post. The matching comment or reply scrolls into view and flashes yellow.
- Follow opens the person's profile. Message opens the chat. Story reaction opens your story.
- `lib/inbox_store.dart` has `LiveEvents.demo`. It simulates other people's activity every 15 seconds so you can test without a server. Set it to `false` when a real backend sends these events.
