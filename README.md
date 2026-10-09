# STRAY-SAFE Analytics

A Flutter dashboard for exploring stray-animal reports. It reads report data
from `assets/reports.csv` and displays summary metrics, status and location
charts, a monthly report trend, and individual case records. Use the priority
filters to update the dashboard.

## Requirements

- Flutter SDK with Dart 3.12.2 or newer (the SDK bundled with Flutter is used).
- A supported device, emulator, or desktop/browser target configured for
  Flutter.

Check that Flutter is installed and available on your `PATH`:

```sh
flutter --version
flutter doctor
```

## Setup

Clone the repository and open a terminal in the project root (the folder
containing `pubspec.yaml`). Then fetch the project dependencies:

```sh
flutter pub get
```

## Run the app

Start the app on a connected or configured Flutter target:

```sh
flutter run
```

To choose a specific target, list available devices and pass its ID:

```sh
flutter devices
flutter run -d <device-id>
```

## Run checks

```sh
flutter analyze
flutter test
```

## Report data

The dashboard loads `assets/reports.csv` as a Flutter asset. Keep the following
header and column order when updating the data:

```text
id,animal,location,priority,status,reported_at,resolved_at
```

- `animal`: for example, `Dog` or `Cat`.
- `priority`: `High`, `Medium`, or `Low`.
- `status`: for example, `Pending`, `Endorsed`, `Escalated`, `Dispatched`,
  `Resolved`, `Rejected`, `Deceased`, `Disputed`, or `Archived`.
- `reported_at` and `resolved_at`: dates in a format accepted by Dart
  `DateTime.parse`, such as `2026-10-01 16:00:00`. Leave `resolved_at` blank
  if the report has not been resolved.

Keep the CSV comma-separated and avoid commas inside field values. If you add
another asset file or change the asset path, also update the asset entry in
`pubspec.yaml`.

Before sharing a real report dataset publicly, remove or anonymize any personal
or otherwise sensitive information.
