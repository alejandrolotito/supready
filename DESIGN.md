---
version: alpha
name: SupReady Design System
---

# Overview
SupReady is a specialized mobile application for aquatic navigation (surfing/water sports). The design system follows the **"UX Anti-Water"** principle: high contrast, oversized elements, and extreme readability to ensure functionality in environments with heavy glare, spray, or wet touch interactions.

# Technical Stack
- **Platform:** Android (Native via Flutter)
- **State Management:** Riverpod
- **Backend:** Firebase (Auth, Firestore)
- **Architecture: Feature-First

# Visual Tokens

## Color Palette (Anti-Water High Contrast)
| Token | Value | Usage |
|---|---|---|
| `background` | `#0F172A` (Slate 900) | Main screen background |
| `surface` | `#1E293B` (Slate 800) | Cards, Containers, Bottom Sheets |
| `primary` | `#06B6D4` (Cyan Neon) | Key navigation, active tracks, alerts |
| `secondary` | `#10B1B1` -> `#10B981` (Emerald) | Community elements, exit points, success |
| `text-main` | `#F1F5F9` (Slate 50) | Headlines and primary body text |
| `text-muted` | `#94A3B8` (Slate 400) | Secondary info, timestamps |

## Typography
- **Headline:** 24px, Black weight (`font-weight: 900`)
- **Body:** 16px, Medium/Regular weight
- **Emphasis:** All interactive elements use high-contrast weights for visibility.

## Layout & Interaction
- **Touch Targets:** Oversized buttons (> 48dp minimum) to accommodate wet fingers or gloves.
- **Spacing:** Generous padding to prevent accidental interaction in high-motion environments.
- **Corners:** Robust rounding (standardized via tokens).

# Data Models (Firestore Reference)
- `/users`: User profiles and session telemetry.
- `/spots`: Navigation locations with real-time weather/tide data.
- `/group_trips`: Group outing management and temporary chat subcollections.
