# STRAY-SAFE Analytics

A Flutter analytics dashboard for stray-animal reports (FRE413 final project).
It reads report data from `assets/reports.csv` and recalculates everything from
that data - nothing is typed in by hand.

## Dashboard components

| Guideline component | Where it is in the app |
| --- | --- |
| KPI cards (3+) | Six cards: Total Reports, Active Cases, Resolution Rate, High Priority, Avg Response, Rejected |
| Graphs (2-3) | Case status donut, reports-by-subdivision bar chart, monthly report trend line (titled, axis-labelled, with legend/tooltips) |
| Records | Case Records table (ID, animal, subdivision, priority, status, reported, resolved, response hours) |
| Search, filter, sort | Search box, priority pills, status filter, subdivision filter, "Sort by" selector + direction toggle, clickable column headers |
| Pagination | Rows-per-page selector (5/10/25/50), previous/next and page-number buttons, "Showing x-y of n records" |
| Interface | Existing STRAY-SAFE orange theme, responsive layout (1/2/3/6-column KPI grid, charts side by side on wide screens) |

The search box and all filters apply to the whole page: the KPI cards, charts,
key findings and records always describe the same filtered set of reports.
A **Key findings** card summarises useful insights computed from the data
(top subdivision, high-priority share, fastest/slowest resolution, busiest
month).

### How the KPI values are calculated

- **Total Reports** - number of rows in the (filtered) data.
- **Active Cases** - reports whose status is not closed (closed = Resolved,
  Rejected, Deceased, Disputed, Archived).
- **Resolution Rate** - Resolved reports / total reports x 100.
- **High Priority** - reports with priority `High` (and how many are still open).
- **Avg Response** - average hours from `reported_at` to `resolved_at` for
  resolved reports.
- **Rejected** - reports with status `Rejected` and their share of the total.

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
