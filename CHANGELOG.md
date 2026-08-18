# Changelog

All notable changes to LemmeGo are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project follows [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-08-18

SemVer baseline established. Version taken as-is from the existing `MARKETING_VERSION` in the Xcode project (not bumped).

- Core NFC-triggered lock sessions, Screen Time app blocking, and the "Lock Now" hybrid remote lock built out
- Screen Time made a hard requirement (PR #6), removing earlier conditional support for devices without FamilyControls
- Emergency unlock system (5/week, Monday reset) added as a safety valve
- Unit test suite added and expanded (LockSession, NFCChip, EmergencyUnlockTracker, FormatTime, BlockedAppsStore) (#10, #12)
- Security / PII audit completed and repo cleared for public release (#11)
- Corrected a stale "App Version 1.0" literal shown on the Settings/About screen to match the shipped `MARKETING_VERSION`
- Still awaiting Apple Family Controls distribution entitlement approval before TestFlight/App Store release
