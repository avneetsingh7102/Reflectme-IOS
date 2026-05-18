# ReflectMe iOS - Knowledge Base

## Project Overview
ReflectMe (branded as **Reflect**) is a voice-first journaling application for iOS that uses AI to transform spoken thoughts into a spatial "Neural Map". It helps users visualize connections between their reflections, identify emotional patterns, and dive deeper into their personal growth.

- **Bundle ID**: `com.reflect.app`
- **Deployment Target**: iOS 17.0+
- **Swift Version**: 5.0
- **Xcode**: 16+
- **Project Generation**: XcodeGen via `project.yml` + `setup.sh`

---

## Architecture Overview

The app follows **Clean Architecture** with clear layer separation:

```
Reflect/
├── App/              # Entry point & root navigation
├── Config/           # DI container, secrets, compile-time config
├── Data/             # Concrete implementations (Persistence, Remote, Speech)
│   ├── Persistence/  # SwiftData models & repository
│   ├── Remote/       # Groq API client & processors
│   └── Speech/       # On-device speech recognition
├── Domain/           # Protocols & pure domain models
│   ├── Models/       # Emotion, NodeCategory, ProcessedEntry
│   └── Services/     # EntryProcessor, DeepDiveService, JournalRepository protocols
├── Presentation/     # All UI (MVVM)
│   ├── Common/       # Reusable views (EmptyStateView, FlowLayout)
│   ├── JournalList/  # Session directory (list, rows, side menu)
│   ├── NeuralMap/    # Spatial graph visualization
│   ├── Recording/    # Voice capture surface
│   ├── Settings/     # App settings
│   └── Tutorial/     # Onboarding flow
└── Theme/            # Centralized design tokens
```

### Pattern: MVVM + Protocol-based DI

- **No singletons.** All services flow through `ServiceContainer` (injected via `@Environment`).
- **ViewModels** are `@Observable` classes, `@MainActor`-isolated.
- **Views** own their ViewModel as `@State` and initialize it from `@Environment(ServiceContainer.self)`.
- **Domain protocols** (`EntryProcessor`, `DeepDiveService`, `JournalRepository`) decouple views from implementations.

---

## Core Functionality

### 1. Voice Capture (Recording Flow)
- **On-device transcription**: `SpeechTranscriber` wraps `SFSpeechRecognizer` + `AVAudioEngine`. Real-time partial results update `transcript`. No audio is uploaded.
- **Recording UI** (`RecordingView`): Full-screen dark surface with pulsing orb, live transcript, waveform bars, elapsed timer, and "Stop & Reflect" CTA.
- **RecordingViewModel** manages three modes:
    - `.newSession` → creates a new `JournalEntry` via repository.
    - `.appendingTo(entry)` → appends transcript to existing entry and re-triggers processing.
    - `.voiceNoteFor(node)` → attaches a timestamped voice note to a specific theme node.
- **Processing**: After recording stops, the transcript is sent to Groq (via `EntryProcessor`) to generate:
    - A 4-7 word poetic title and one-sentence summary.
    - 3-5 theme nodes with category + emotion.
    - Up to 5 relationship edges between themes.

### 2. Neural Map (Visualization)
- **Spatial graph**: Displays themes as a force-directed graph of draggable bubbles.
- **NeuralMapViewModel** orchestrates:
    - Auto-processing entries with `retryPending == true`.
    - `ForceDirectedLayout` for positioning nodes that lack persisted coordinates.
    - Category filtering (Self, Relationships, Growth, Authenticity).
    - Deep-dive expansion (lazy-loads expanded content per node via `DeepDiveService`).
    - Drag-to-reposition with position persistence.
- **Sub-views**:
    - `ThoughtNodeView`: Individual theme bubble, colored by emotion.
    - `EdgePath`: Lines connecting related themes.
    - `NodeDetailSheet`: Expanded reflection, voice notes, emotion badge.
    - `EdgeExplanationSheet`: Shows relationship label between two nodes.
    - `TranscriptSheet`: Full raw transcript viewer.
    - `FilterPill`: Category filter chip.
    - `PositionedNode`: Layout model (id, label, position, category, emotion, weight).

### 3. Journal Management (List Flow)
- **JournalListView**: Chronological list of all entries with month-grouped sections.
- **JournalListViewModel** provides:
    - Filtering: All, by Emotion, This Week, This Month.
    - Full-text search across title, summary, transcript, and node labels.
    - Month-bucketed grouping for sectioned rendering.
    - Swipe-to-delete.
- **JournalRowView**: Entry card showing title, summary, date, and emotion pills.
- **SideMenuView**: Slide-out navigation (settings, tutorial, color guide).
- **Persistence**: SwiftData-backed via `SwiftDataJournalRepository`.
- **Entry creation flow**: `handleNewEntry` explicitly calls `modelContext.save()` before dismissing the `.fullScreenCover`, then navigates to `NeuralMapView` after a 500ms delay for animation.

### 4. Deep Dive (Theme Expansion)
- **AI-generated reflections**: When the user taps a node, `DeepDiveService.expand()` generates a 2-3 paragraph reflection on that theme.
- Includes quoted sentences from the transcript, emotional analysis, and a contextual follow-up question.
- Uses a fast small model (`llama-3.1-8b-instant`) for low latency on the detail sheet.

### 5. Settings
- **SettingsView**: App version, total reflections count, dark mode toggle, destructive "clear all reflections", source code link, credits.
- Dark mode uses `@AppStorage("isDarkMode")` and applies via `.preferredColorScheme`.

### 6. Tutorial / Onboarding
- **TutorialView**: 4-step guide (Speak → See → Explore → Patterns).
- **ColorGuideView**: Explains the emotion-to-color mapping.
- **PrivacyView**: Privacy information.

### 7. Authentication & Account
- **LoginView**: Gated entry point requiring authentication via **Apple ID** or **Google Sign-In**.
- **AuthService**: Protocol-based abstraction for identity management.
- **SupabaseAuthService**: Implementation using Supabase Auth SDK.
- **Secure Sessions**: Automatically handles token persistence and session recovery.
- **Sign Out**: Destructive action in `SettingsView` that ends the session and returns user to `LoginView`.

---

## Data Layer

### SwiftData Models

**`JournalEntry`** (`@Model`)
| Field | Type | Notes |
|---|---|---|
| `id` | `String` (unique) | UUID string |
| `date` | `Date` | Creation timestamp |
| `rawTranscript` | `String` | Original spoken text |
| `polishedTranscript` | `String` | Copy after processing |
| `aiGeneratedTitle` | `String` | LLM-generated poetic title |
| `oneLineSummary` | `String` | LLM-generated summary |
| `retryPending` | `Bool` | `true` = needs processing |
| `processingFailed` | `Bool?` | `true` = last attempt failed |
| `artMovement` | `String?` | Reserved for future visual-style tagging |
| `mapNodes` | `[SDNode]` | Cascade-delete relationship |
| `mapLinks` | `[SDLink]` | Cascade-delete relationship |

**`SDNode`** (`@Model`)
| Field | Type | Notes |
|---|---|---|
| `id` | `String` (unique) | Slug from LLM |
| `label` | `String` | Human-readable theme name |
| `categoryKey` | `String` | Stored as string, parsed via `NodeCategory(apiString:)` |
| `emotionKey` | `String` | Stored as string, parsed via `Emotion(apiString:)` |
| `weight` | `Int` | Visual prominence (default 3 for new nodes, 1 for init) |
| `expandedContent` | `String?` | Lazy-loaded deep-dive text |
| `voiceNotes` | `[String]` | Timestamped voice note transcripts |
| `positionX` / `positionY` | `Double?` | Persisted map position |
| `session` | `JournalEntry?` | Inverse relationship |

**`SDLink`** (`@Model`)
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | Auto-generated |
| `source` / `target` | `String` | Node IDs |
| `value` | `Int` | Edge weight |
| `relationship` | `String?` | One-word label from LLM |
| `session` | `JournalEntry?` | Inverse relationship |

### Domain Models

**`Emotion`** (enum, 8 cases): `joy`, `sadness`, `anger`, `fear`, `curiosity`, `gratitude`, `regret`, `neutral`. Each has a `label`, `iconName` (SF Symbol), and `prefersDarkText` flag.

**`NodeCategory`** (enum): `.self`, `.relationships`, `.growth`, `.authenticity`, `.other(String)`. Parsed from LLM output, falls back to `.other` for unknown values.

**`ProcessedEntry`** (struct): Output of `EntryProcessor` — contains `title`, `summary`, `nodes: [ProcessedNode]`, `edges: [ProcessedEdge]`.

### Repository Protocol (`JournalRepository`)
All mutations go through this `@MainActor` protocol:
- `createEntry(rawTranscript:)` → `JournalEntry`
- `appendTranscript(_:to:)` — re-triggers processing
- `apply(_:to:)` — applies LLM results, inserts nodes/edges
- `markFailed(_:)` — sets failure state
- `delete(_:)`
- `setExpandedContent(_:for:)` — deep-dive text
- `appendVoiceNote(_:to:)` — timestamped note
- `setPosition(_:for:)` — drag position

### Hybrid Sync Pattern (`SyncingJournalRepository`)
The app uses a decorator pattern to achieve seamless cloud synchronization:
1. **Local Priority**: All write operations hit `SwiftDataJournalRepository` first for zero-latency UI updates and offline support.
2. **Background Mirroring**: `SyncingJournalRepository` intercepts these calls and dispatches asynchronous tasks to `SupabaseSyncService`.
3. **Data Integrity**: Uses Postgres `upsert` (on conflict do update) to ensure local and remote states stay eventual consistent.
4. **Isolation**: Row Level Security (RLS) in Supabase ensures data is scoped to the `auth.uid()`.

---

## Service Layer

### ServiceContainer (Composition Root)
- `@Observable final class`, passed via `@Environment`.
- Holds `entryProcessor: any EntryProcessor`, `deepDiveService: any DeepDiveService`, and `authService: any AuthService`.
- `ServiceContainer.live()` creates the wiring: `GroqClient` + `SupabaseAuthService` → `GroqEntryProcessor` + `GroqDeepDiveService` + `SyncingJournalRepository`.

### GroqClient (actor)
- Shared HTTP client for Groq's OpenAI-compatible `/v1/chat/completions` endpoint.
- `completeJSON<T>(model:systemPrompt:userPrompt:...)` — expects `response_format: json_object`, decodes as `T`.
- `completeText(model:systemPrompt:userPrompt:...)` — returns raw trimmed text.
- Validates API key on every call (fails fast if placeholder).
- Error types: `missingAPIKey`, `http(statusCode:body:)`, `emptyContent`, `undecodableContent`.

### GroqEntryProcessor (actor, implements `EntryProcessor`)
- Default model: `llama-3.3-70b-versatile`.
- Single LLM call produces title + summary + theme graph (3-5 nodes, ≤5 edges).
- Validates edges reference existing node IDs.

### GroqDeepDiveService (actor, implements `DeepDiveService`)
- Default model: `llama-3.1-8b-instant`.
- Generates 2-3 paragraph reflection with quotes, emotional analysis, and a follow-up question.

### SpeechTranscriber (`@Observable`, `@MainActor`)
- Wraps `SFSpeechRecognizer` + `AVAudioEngine`.
- On-device only, no audio upload.
- Requests mic + speech permissions, exposes `transcript`, `isRecording`, `authorizationStatus`.

---

## Theme Layer (`ReflectTheme`)

**Design Philosophy**: Warm Minimalism — paper-warm canvas, soft cards, burnt-orange accent.

### Surfaces
| Token | Hex | Usage |
|---|---|---|
| `canvas` | `#FCF9F3` | Background |
| `cardSurface` | `#F6F3ED` | Card fills |
| `cardElevated` | `#FFFFFF` | Elevated cards |
| `darkCanvas` | `#31312D` | Dark mode / recording BG |
| `darkSurface` | `#1C1C18` | Dark elevated |

### Accent
- Primary: `#A03B00` (burnt orange)
- Light variant: `#C74E08`
- Gradient: `accentGradient` (topLeading → bottomTrailing)

### Emotion Colors
| Emotion | Hex |
|---|---|
| Joy | `#FFD700` |
| Sadness | `#6B9BD1` |
| Anger | `#D14B4B` |
| Fear | `#9B6BD1` |
| Curiosity | `#4BD1C5` |
| Gratitude | `#FF9A56` |
| Regret | `#8E8E93` |
| Neutral | `#D1D1D6` |

### Category Colors
| Category | Hex |
|---|---|
| Self | `#A569BD` |
| Relationships | `#F08080` |
| Growth | `#48C9B0` |
| Authenticity | `#F5B041` |
| Other | `#9FA8DA` |

### Typography
- `serif(_:weight:)` → `.system(design: .serif)` — titles, headings
- `rounded(_:weight:)` → `.system(design: .rounded)` — body, labels
- `mono(_:weight:)` → `.system(design: .monospaced)` — timestamps, data

### Spacing Scale
`XS=4, SM=8, MD=16, LG=24, XL=32, XXL=48, Huge=64`

### Corner Radii
`XS=4, SM=8, MD=12, LG=16, XL=24, Full=9999`

### Animations
- `springSnappy`: response=0.35, damping=0.75
- `springGentle`: response=0.5, damping=0.8
- `springBouncy`: response=0.4, damping=0.6

### Helpers
- `ReflectTheme.greeting` / `.greetingEmoji` — time-of-day based
- `nodeDiameter(prominence:)` — 72–136pt based on weight
- `.reflectCard()` view modifier — card styling
- `.accentGlow()` view modifier — orange shadow
- `Color(hex:)` initializer (3/6/8 digit hex)

---

## Configuration & Secrets

### AppConfig
- `placeholderAPIKey` = `"PASTE_YOUR_GROQ_KEY_HERE"`
- `entryProcessorModel` = `"llama-3.3-70b-versatile"`
- `deepDiveModel` = `"llama-3.1-8b-instant"`
- `supabaseURL` = Project URL from dashboard
- `supabaseAnonKey` = Public API key for client-side access

### SecretsLoader
- Reads `Secrets.plist` from the app bundle.
- `.gitignored` — copy `Secrets.example.plist` and fill in `GROQ_API_KEY`.

---

## Development Guidelines
- **Build**: Open `Reflect.xcodeproj` in Xcode 16+ or use `xcodebuild`.
- **Project Generation**: If `.xcodeproj` is corrupted, run `./setup.sh` (uses XcodeGen with `project.yml`).
- **Dependencies**: Uses Swift Package Manager (managed via XcodeGen). Includes `Supabase` for backend integration.
- **Secrets**: Copy `Secrets.example.plist` → `Secrets.plist`, add your Groq API key.
- **Database**: Postgres tables must be created via Supabase SQL Editor.

---

## Known Issues & Gotchas

### SwiftData + `.fullScreenCover` @Query reactivity
- `@Query` may not immediately reflect entries created inside a `.fullScreenCover`. **Fix**: call `modelContext.save()` explicitly before setting `showCover = false`.

### ZStack touch handling
- Views with `.frame(maxWidth: .infinity, maxHeight: .infinity)` in a `ZStack` can block touches on buttons behind them. **Fix**: `EmptyStateView` uses `padding(.bottom, 140)` to keep clear of the `PulsingOrbButton`.

### Swift Concurrency & Conformance Thread-Safety
- Conforming a `@MainActor`-isolated class (like `SupabaseAuthService`) to a protocol with non-isolated properties/methods will trigger Swift 6 data race warnings or compile errors. **Fix**: Mark the protocol itself (e.g., `AuthService`) as `@MainActor` to guarantee thread safety for all UI-driving state properties.

### SwiftData ModelContainer Initialization Crash
- SwiftData can fail to create `ModelContainer` with a `loadIssueModelContainer` error when booting the app in simulators or devices under certain configuration states. **Fix**: Construct the `ModelContainer` on the `@MainActor` with a custom `ModelConfiguration(isStoredInMemoryOnly: false)` explicitly configured, rather than using the default implicit initializer.

### Swift Access Control Levels in Single-Targets
- Declaring classes/methods as `public` in a single-target app causes compiler errors when they interact with default `internal` types (like `@Model` classes). **Fix**: Keep all repository and backend service layers standard `internal` (omit `public`), which allows seamless target-internal type visibility without exposing API boundaries.

### Supabase SDK Deprecations
- Using `client.database.from(...)` is deprecated in modern Supabase Swift SDKs. **Fix**: Call the direct database accessor `client.from(...)` directly on the client.

### Terminal Building without Code Signing
- Building the app via the command line default configurations often fails due to missing Development Team signing configurations. **Fix**: Build targeting the iOS Simulator SDK (`-sdk iphonesimulator -destination "generic/platform=iOS Simulator"`) which bypasses team signing validation checks.

---

## File Inventory (57 Swift files)

### App (2)
- `ReflectApp.swift` — `@main`, explicit `ModelContainer`
- `ContentView.swift` — Root navigation, gates app behind `LoginView`

### Config (3)
- `AppConfig.swift` — models, Supabase keys, backend URL
- `SecretsLoader.swift` — reads `Secrets.plist`
- `ServiceContainer.swift` — DI composition root, handles Auth/Sync wiring

### Data/Persistence (4)
- `JournalEntry.swift` — `@Model` core session
- `SDNode.swift` — `@Model` theme node
- `SDLink.swift` — `@Model` edge
- `SwiftDataJournalRepository.swift` — local persistence implementation

### Data/Remote (6)
- `GroqClient.swift` — HTTP client actor
- `GroqEntryProcessor.swift` — transcript → graph
- `GroqDeepDiveService.swift` — theme → reflection
- `SupabaseAuthService.swift` — Auth implementation
- `SupabaseSyncService.swift` — Remote database API
- `SyncingJournalRepository.swift` — Decorator for local+remote sync

### Data/Speech (1)
- `SpeechTranscriber.swift` — on-device STT

### Domain/Models (3)
- `Emotion.swift` — 8-case enum
- `NodeCategory.swift` — 4+other enum
- `ProcessedEntry.swift` — DTOs

### Domain/Services (4)
- `EntryProcessor.swift` — protocol
- `DeepDiveService.swift` — protocol
- `JournalRepository.swift` — protocol
- `AuthService.swift` — protocol for identity

### Presentation/Auth (1)
- `LoginView.swift` — Apple & Google sign-in surface

### Presentation/Common (2)
- `EmptyStateView.swift` — empty list placeholder
- `FlowLayout.swift` — wrapping horizontal layout

### Presentation/JournalList (4)
- `JournalListView.swift` — main list screen
- `JournalListViewModel.swift` — filter, search, grouping
- `JournalRowView.swift` — entry card
- `SideMenuView.swift` — slide-out menu

### Presentation/NeuralMap (10)
- `NeuralMapView.swift` — main canvas
- `NeuralMapViewModel.swift` — processing, layout, deep dive
- `ThoughtNodeView.swift` — theme bubble
- `EdgePath.swift` — connection line
- `NodeDetailSheet.swift` — expanded reflection sheet
- `EdgeExplanationSheet.swift` — edge label sheet
- `TranscriptSheet.swift` — full transcript
- `FilterPill.swift` — category chip
- `ForceDirectedLayout.swift` — physics layout
- `PositionedNode.swift` — layout model

### Presentation/Recording (4)
- `RecordingView.swift` — full-screen capture
- `RecordingViewModel.swift` — recording lifecycle
- `PulsingOrbButton.swift` — animated mic button
- `WaveformBarsView.swift` — audio waveform

### Presentation/Settings (1)
- `SettingsView.swift` — app settings

### Presentation/Tutorial (3)
- `TutorialView.swift` — how-it-works guide
- `ColorGuideView.swift` — emotion color legend
- `PrivacyView.swift` — privacy info

### Theme (1)
- `ReflectTheme.swift` — all design tokens
