# Vanish Class Network

## Project Overview

Vanish Class Network is a Flutter-based messaging application that allows users to exchange temporary messages. Messages have a 30-second expiry period and disappear from the chat when their expiry time is reached.

The application uses a shared WebSocket relay server to exchange messages between connected devices.

## Main Features

- Send and receive messages between connected devices.
- Automatic 30-second message expiry.
- Countdown timer for each message.
- WebSocket-based communication.
- Offline message queue and reconnection handling.
- Local message storage using SQLite.
- Expired-message cleanup.

## Technologies Used

- **Frontend:** Flutter
- **Programming Language:** Dart
- **Local Database:** SQLite
- **Communication:** WebSocket
- **Message Format:** JSON
- **Development Environment:** Android Studio / Visual Studio Code

## Platform

The application was developed using Flutter for Android.

It was tested on:
- Android physical device
- Android Emulator

## Relay Server

The application uses the following WebSocket relay address:

`wss://vanish-relay-sawaira.bonto.page/ws`

The relay handles message exchange and provides server timestamps used for message expiry calculations.

## How to Run the Project

### Requirements

- Flutter SDK
- Dart SDK
- Android Studio or Visual Studio Code
- Android device or emulator

### Installation Steps

1. Clone the repository:

   `git clone https://github.com/shaziakanwalofficial2006-cloud/vanish-class-network.git`

2. Open the project folder:

   `cd vanish-class-network`

3. Install dependencies:

   `flutter pub get`

4. Run the application:

   `flutter run`

## Build APK

To generate a release APK, run:

`flutter build apk --release`

The generated APK is located at:

`build/app/outputs/flutter-apk/app-release.apk`

## Message Expiry and Limitations

Messages are designed to disappear after 30 seconds according to the relay-provided expiry timestamp.

This application cannot guarantee protection against screenshots, copying, or photographing messages. Local database cleanup and relay memory are separate from the disappearance of a message from the chat interface.

## Repository

GitHub: https://github.com/shaziakanwalofficial2006-cloud/vanish-class-network

## Project Team

- Shazia Kanwal
- Kanwal Muskan Latif
- Alisha Gul
