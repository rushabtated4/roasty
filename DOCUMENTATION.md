# Savage Streak - Flutter Habit Tracker

A Flutter-based habit tracking application that uses AI-generated motivational content and "roasts" to help users maintain their daily habits. The app features a unique approach to habit formation by combining accountability with humor.

## 🚀 Features

### Core Functionality
- **Single Habit Focus**: Designed to track one habit at a time for maximum focus
- **AI-Generated Content**: Dynamic motivational messages and "roasts" based on user performance
- **Streak Tracking**: Visual streak counter with emoji calendar
- **Customizable Tone**: Choose from motivational, mild, medium, or brutal messaging styles
- **Smart Notifications**: Configurable reminder system with escalation
- **Dark Theme**: Modern dark UI with green accent colors

### User Experience
- **Onboarding Flow**: 3-step setup process for habit creation
- **Daily Tracking**: Simple done/missed status tracking
- **Calendar View**: Monthly habit tracking with emoji indicators
- **Settings Management**: Comprehensive app configuration
- **Data Archiving**: Save completed habits to history

## 🏗️ Architecture

### Project Structure
```
roasty/
├── main.dart                    # App entry point and splash screen
├── theme.dart                   # App theming and styling
├── onboarding_page.dart         # User onboarding flow
├── main_tracker_page.dart       # Main habit tracking interface
├── settings_page.dart           # App settings and configuration
├── database_service.dart        # SQLite database operations
├── openai_service.dart          # AI content generation
├── notification_service.dart    # Push notification management
├── emoji_calendar.dart          # Calendar widget component
├── roast_loading_dialog.dart    # Loading dialog for AI generation
├── habit_modal.dart             # Habit editing modal
├── superwall_paywall.dart       # Premium features paywall
├── AndroidManifest.xml          # Android app configuration
└── info.plist                   # iOS app configuration
```

### Technology Stack
- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Database**: SQLite (sqflite)
- **AI Integration**: OpenAI GPT-4 API
- **Notifications**: flutter_local_notifications + Workmanager
- **UI**: Material Design 3 with custom dark theme
- **Fonts**: Google Fonts (Inter)

## 📱 Screens & Navigation

### 1. Splash Screen (`main.dart`)
- App branding with fire emoji
- Automatic navigation based on existing habit
- 1-second delay for visual effect

### 2. Onboarding Flow (`onboarding_page.dart`)
**Step 1: Habit Selection**
- Predefined habit options (Gym, No Sugar, Reading, etc.)
- Custom habit input option
- Emoji-based visual selection

**Step 2: Reason Input**
- Text input for habit motivation
- Required field validation

**Step 3: Tone Selection**
- Motivational, Mild, Medium, Brutal options
- Affects AI-generated content style

### 3. Main Tracker (`main_tracker_page.dart`)
- Current streak display
- Today's habit status (Done/Missed)
- AI-generated motivational content
- Monthly calendar view
- Settings access

### 4. Settings (`settings_page.dart`)
- Notification preferences
- Reminder time configuration
- Habit reset and archiving
- Data management options

## 🗄️ Data Models

### HabitModel
```dart
{
  id: int,
  title: String,           // Habit name
  reason: String,          // User's motivation
  tone: String,            // Content style preference
  plan: String,            // Subscription tier
  startedAt: DateTime,     // Habit start date
  reminderTime: String,    // Notification time (HH:MM)
  currentStreak: int,      // Current streak count
  consecutiveMisses: int,  // Missed days counter
  escalationState: int     // AI escalation level
}
```

### EntryModel
```dart
{
  id: int,
  habitId: int,           // Reference to habit
  entryDate: DateTime,    // Entry date
  status: String,         // 'pending', 'done', 'missed', 'future'
  roastScreen: String,    // AI content for main screen
  roastDone: String,      // AI content for completion
  roastMissed: String     // AI content for missed days
}
```

## 🔧 Services

### DatabaseService
- **SQLite Database**: Local storage with 4 tables
  - `habit`: Current active habit
  - `entry`: Daily habit entries
  - `archive_habit`: Completed habits history
  - `archive_entry`: Archived daily entries
- **CRUD Operations**: Full database management
- **Streak Calculation**: Automatic streak computation
- **Data Archiving**: Move completed habits to history

### OpenAIService
- **GPT-4 Integration**: AI content generation
- **Dynamic Prompts**: Context-aware roast generation
- **Fallback System**: Dummy content when API fails
- **Tone Adaptation**: Content style based on user preference
- **Batch Generation**: Pre-generate 7 days of content

### NotificationService
- **Local Notifications**: Daily habit reminders
- **Workmanager**: Background task scheduling
- **Permission Management**: iOS/Android permission handling
- **Escalation**: Multiple reminder levels
- **Auto-miss Detection**: Midnight status updates

## 🎨 UI/UX Design

### Theme System (`theme.dart`)
- **Dark Theme**: Primary color scheme
- **Brand Colors**: 
  - Primary: `#00D07E` (Green)
  - Error: `#FF3B30` (Red)
  - Background: `#000000` (Black)
  - Surface: `#111111` (Dark Gray)
- **Typography**: Inter font family
- **Components**: Material 3 design system

### Key Components
- **Emoji Calendar**: Visual habit tracking
- **Loading Dialogs**: AI generation feedback
- **Custom Buttons**: Rounded, branded styling
- **Progress Indicators**: Onboarding flow progress

## 🚀 Setup & Installation

### Prerequisites
- Flutter SDK 3.x
- Dart SDK 3.x
- iOS Simulator or Android Emulator
- OpenAI API Key

### Dependencies
```yaml
# Core Flutter packages
flutter_riverpod: ^2.x.x
sqflite: ^2.x.x
path: ^1.x.x

# AI & Notifications
http: ^1.x.x
flutter_local_notifications: ^16.x.x
workmanager: ^0.5.x

# UI & Styling
google_fonts: ^6.x.x
shared_preferences: ^2.x.x

# Platform-specific
# iOS: Add to info.plist
# Android: Add to AndroidManifest.xml
```

### Configuration
1. **OpenAI API Key**: Replace `'OPENAI-API-KEY'` in `openai_service.dart`
2. **iOS Permissions**: Configure `info.plist` for notifications
3. **Android Permissions**: Update `AndroidManifest.xml` for background tasks

### Build Commands
```bash
# Install dependencies
flutter pub get

# Run on iOS
flutter run -d ios

# Run on Android
flutter run -d android

# Build release
flutter build apk --release
flutter build ios --release
```

## 🔄 App Flow

### First Launch
1. Splash screen displays
2. Check for existing habit
3. Navigate to onboarding if no habit exists
4. Complete 3-step onboarding process
5. Generate initial AI content
6. Navigate to main tracker

### Daily Usage
1. Open app to main tracker
2. View today's AI-generated content
3. Mark habit as done or missed
4. Update streak counter
5. Generate new AI content for future days
6. View calendar progress

### Settings Management
1. Access settings from main tracker
2. Configure notification preferences
3. Set reminder times
4. Archive or reset current habit
5. Manage app data

## 🧠 AI Content Generation

### Content Types
- **Screen Content**: Main motivational message
- **Done Content**: Completion celebration
- **Missed Content**: Missed day response

### Tone Variations
- **Motivational**: Encouraging and supportive
- **Mild**: Light teasing with encouragement
- **Medium**: Moderate accountability with humor
- **Brutal**: Harsh but humorous motivation

### Context Factors
- Current streak length
- Consecutive missed days
- Escalation state
- User's personal reason
- Habit type

## 📊 Data Management

### Local Storage
- SQLite database for all user data
- SharedPreferences for app settings
- Automatic data backup through archiving

### Data Operations
- **Create**: New habit and daily entries
- **Read**: Current habit, calendar data, settings
- **Update**: Streak counts, entry status, preferences
- **Delete**: Reset habits, clear all data
- **Archive**: Move completed habits to history

### Privacy
- All data stored locally on device
- No cloud synchronization
- User controls all data deletion

## 🔧 Development Notes

### State Management
- Riverpod for global state
- StateNotifierProvider for habit and entries
- ConsumerStatefulWidget for reactive UI

### Error Handling
- Graceful fallbacks for API failures
- User-friendly error messages
- Robust database operations

### Performance
- Efficient database queries
- Lazy loading of calendar data
- Background task optimization

## 🚀 Future Enhancements

### Potential Features
- Multiple habit support
- Social sharing
- Achievement badges
- Custom AI prompts
- Cloud synchronization
- Widget support
- Apple Watch integration

### Technical Improvements
- Unit and widget testing
- Performance optimization
- Accessibility improvements
- Internationalization
- Analytics integration

## 📄 License

This project is proprietary software. All rights reserved.

## 👥 Contributing

This is a private project. For questions or support, please contact the development team.

---

**Savage Streak** - One habit. No excuses. 🔥 