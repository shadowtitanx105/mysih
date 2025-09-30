# Loan Utilization App - Architecture & User Flows

## Architecture Overview

### Design Pattern: Clean Architecture + MVVM
- **Presentation Layer**: UI widgets and view models (Provider for state management)
- **Domain Layer**: Business logic, use cases, and entities
- **Data Layer**: Repositories, data sources (local SQLite, remote API)
- **Core Layer**: Utilities, services, constants, and shared code

### Folder Structure
```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── database/
│   │   ├── database_helper.dart
│   │   ├── dao/
│   │   │   ├── user_dao.dart
│   │   │   ├── loan_dao.dart
│   │   │   ├── media_dao.dart
│   │   │   └── sync_queue_dao.dart
│   │   └── migrations/
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── location_service.dart
│   │   ├── media_service.dart
│   │   ├── sync_service.dart
│   │   ├── ai_validation_service.dart
│   │   └── network_service.dart
│   ├── utils/
│   │   ├── constants.dart
│   │   ├── validators.dart
│   │   ├── date_utils.dart
│   │   └── encryption_utils.dart
│   └── providers/
│       ├── auth_provider.dart
│       ├── connectivity_provider.dart
│       └── sync_provider.dart
├── models/
│   ├── user_model.dart
│   ├── beneficiary_model.dart
│   ├── loan_model.dart
│   ├── media_submission_model.dart
│   └── officer_model.dart
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── otp_verification_screen.dart
│   │   │   └── role_selection_screen.dart
│   │   ├── widgets/
│   │   └── providers/
│   ├── beneficiary/
│   │   ├── screens/
│   │   │   ├── beneficiary_home_screen.dart
│   │   │   ├── loan_details_screen.dart
│   │   │   ├── media_upload_screen.dart
│   │   │   ├── camera_capture_screen.dart
│   │   │   └── submission_history_screen.dart
│   │   ├── widgets/
│   │   └── providers/
│   └── officer/
│       ├── screens/
│       │   ├── officer_home_screen.dart
│       │   ├── loan_entry_screen.dart
│       │   ├── review_submissions_screen.dart
│       │   ├── submission_detail_screen.dart
│       │   └── beneficiary_management_screen.dart
│       ├── widgets/
│       └── providers/
└── shared/
    └── widgets/
        ├── custom_button.dart
        ├── custom_textfield.dart
        ├── loading_indicator.dart
        └── error_dialog.dart
```

## User Flows

### 1. Authentication Flow (OTP-Based)

**Beneficiary Login Flow:**
```
Start
  ↓
[Login Screen]
  ↓ Enter Mobile Number
[Validate Format (10 digits)]
  ↓ Valid
[Send OTP via SMS/Firebase Auth]
  ↓
[OTP Verification Screen]
  ↓ Enter OTP (6 digits)
[Verify OTP]
  ↓ Success
[Check User Role in Local DB]
  ↓ Is Beneficiary?
    Yes → [Beneficiary Home Screen]
    No → [Show Error: Access Denied]
```

**Officer Login Flow:**
```
Start
  ↓
[Login Screen]
  ↓ Enter Mobile Number
[Validate Format]
  ↓
[Send OTP]
  ↓
[OTP Verification Screen]
  ↓ Enter OTP
[Verify OTP]
  ↓ Success
[Check User Role]
  ↓ Is Officer?
    Yes → [Officer Home Screen]
    No → [Show Error: Access Denied]
```

### 2. Beneficiary Module - Media Upload Flow

```
[Beneficiary Home Screen]
  ↓
[View Active Loans List]
  ↓ Select Loan
[Loan Details Screen]
  ↓ Tap "Upload Evidence"
[Media Upload Screen]
  ↓
[Choose Option]
  ├── Take Photo
  │     ↓
  │   [Camera Capture Screen]
  │     ↓ Request Permissions (Camera, Location)
  │     ↓ Capture Photo
  │     ↓ Get GPS Coordinates
  │     ↓ Get Timestamp
  │     ↓
  │   [Preview Screen]
  │     ↓ Add Description
  │     ↓ Confirm
  │     ↓
  │   [Save to Local DB with sync_status='pending']
  │     ↓
  │   [Check Internet Connection]
  │     ├── Online → [Upload to Server] → [Update sync_status='synced']
  │     └── Offline → [Show "Saved Locally, will sync when online"]
  │
  └── Record Video
        ↓
      [Camera Capture Screen - Video Mode]
        ↓ Record (max 30 seconds)
        ↓ Get GPS + Timestamp
        ↓
      [Preview & Save]
        ↓
      [Same sync logic as photo]
```

### 3. Officer Module - Loan Entry Flow

```
[Officer Home Screen]
  ↓ Tap "Add New Loan"
[Loan Entry Screen]
  ↓
[Fill Form]
  ├── Search/Select Beneficiary (by mobile/code)
  ├── Enter Loan Amount
  ├── Select Scheme
  ├── Enter Purpose
  ├── Set Sanction Date
  └── Add Remarks
  ↓ Submit
[Validate All Fields]
  ↓ Valid
[Save to Local DB]
  ↓
[Check Internet]
  ├── Online → [Sync to Server]
  └── Offline → [Add to Sync Queue]
  ↓
[Show Success Message]
  ↓
[Return to Officer Home]
```

### 4. Officer Module - Review Submissions Flow

```
[Officer Home Screen]
  ↓ Tap "Review Submissions"
[Review Submissions Screen]
  ↓
[Display Filters]
  ├── Status: Pending/All
  ├── Date Range
  └── Beneficiary
  ↓
[List of Submissions]
  ↓ Tap on Submission
[Submission Detail Screen]
  ↓
[Display Information]
  ├── Media (Photo/Video Player)
  ├── Location on Map
  ├── Timestamp
  ├── Beneficiary Details
  ├── Loan Details
  ├── AI Validation Score (if available)
  └── Description
  ↓
[Officer Actions]
  ├── Approve
  │   ↓ Add Remarks (optional)
  │   ↓ Confirm
  │   ↓ Update status='approved'
  │   ↓ Save & Sync
  │
  ├── Reject
  │   ↓ Add Remarks (mandatory)
  │   ↓ Confirm
  │   ↓ Update status='rejected'
  │   ↓ Save & Sync
  │
  └── Request More Info
      ↓ Send notification to beneficiary
      ↓ Update status='under_review'
```

### 5. Offline Sync Flow

```
[App Running in Background]
  ↓
[Connectivity Monitor]
  ↓ Internet Available?
  ↓ Yes
[Check Sync Queue]
  ↓ Has Pending Items?
  ↓ Yes
[For Each Item in Queue]
  ├── Process Upload/Update
  ├── Retry Logic (max 3 attempts)
  ├── On Success:
  │     ├── Update sync_status='synced'
  │     └── Remove from queue
  └── On Failure:
        ├── Increment retry_count
        ├── Log error
        └── Keep in queue
  ↓
[Show Sync Status Notification]
  ├── "All data synced successfully"
  └── "X items pending sync"
```

## Screen Wireframes (Text-Based)

### Login Screen
```
┌─────────────────────────────┐
│  [App Logo]                 │
│                             │
│  Loan Utilization System    │
│                             │
│  ┌───────────────────────┐  │
│  │ Mobile Number         │  │
│  │ +91 [__________]      │  │
│  └───────────────────────┘  │
│                             │
│  [Send OTP Button]          │
│                             │
│  Terms & Conditions         │
└─────────────────────────────┘
```

### OTP Verification Screen
```
┌─────────────────────────────┐
│  ← Back                     │
│                             │
│  Verify Mobile Number       │
│  OTP sent to +91-XXXXX-XX23 │
│                             │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐       │
│  │  │ │  │ │  │ │  │       │
│  └──┘ └──┘ └──┘ └──┘       │
│                             │
│  [Verify Button]            │
│                             │
│  Didn't receive? Resend (45s)│
└─────────────────────────────┘
```

### Beneficiary Home Screen
```
┌─────────────────────────────┐
│  ☰  Home         [Profile]  │
├─────────────────────────────┤
│  Welcome, [Name]            │
│  Beneficiary ID: XXXXX      │
│                             │
│  ┌─────────────────────┐    │
│  │ Active Loans        │    │
│  │                     │    │
│  │ [Loan Card 1]       │    │
│  │  Scheme: PMMY       │    │
│  │  Amount: ₹50,000    │    │
│  │  [Upload Evidence]  │    │
│  │                     │    │
│  │ [Loan Card 2]       │    │
│  │  ...                │    │
│  └─────────────────────┘    │
│                             │
│  [View History]             │
│  [Sync Status: ●]           │
└─────────────────────────────┘
```

### Camera Capture Screen
```
┌─────────────────────────────┐
│  [Camera Preview]           │
│                             │
│  🎥 [Full Screen]           │
│                             │
│  Location: ● Acquired       │
│  Time: 10:30 AM             │
│                             │
│  ┌───────────────────┐      │
│  │ [Gallery] [●] [↻] │      │
│  └───────────────────┘      │
└─────────────────────────────┘
```

### Officer Review Screen
```
┌─────────────────────────────┐
│  ← Back    Review Submissions│
├─────────────────────────────┤
│  Filters: [Pending ▼] [Date]│
│                             │
│  ┌─────────────────────┐    │
│  │ [Thumbnail]         │    │
│  │ Ben: Rajesh Kumar   │    │
│  │ Loan: PMMY-2024-001 │    │
│  │ Date: 25 Sep 2024   │    │
│  │ Status: 🟡 Pending  │    │
│  └─────────────────────┘    │
│                             │
│  ┌─────────────────────┐    │
│  │ [Thumbnail]         │    │
│  │ ...                 │    │
│  └─────────────────────┘    │
└─────────────────────────────┘
```

### Submission Detail Screen (Officer)
```
┌─────────────────────────────┐
│  ← Back    Submission Detail │
├─────────────────────────────┤
│  [Media Display - Full Width]│
│  [Play Button for Video]    │
│                             │
│  📍 Location                 │
│  Lat: 28.6139, Lon: 77.2090 │
│  [View on Map]              │
│                             │
│  🕐 Captured: 25-09-2024    │
│     10:30 AM                │
│                             │
│  Beneficiary: Rajesh Kumar  │
│  Loan ID: PMMY-2024-001     │
│  Purpose: Dairy Equipment   │
│                             │
│  AI Validation: ✓ 87% Match│
│                             │
│  Description:               │
│  "Purchased milking machine"│
│                             │
│  ┌──────────────────────┐   │
│  │ Officer Remarks:     │   │
│  │ [Text Input]         │   │
│  └──────────────────────┘   │
│                             │
│  [Approve] [Reject]         │
└─────────────────────────────┘
```

## AI/ML Integration Plan

### Phase 1: Stub Implementation (Current)
- Mock validation service that returns random scores
- Simulates processing time
- Always returns basic validation result

### Phase 2: Rule-Based Validation
- Check image/video quality (resolution, blur detection)
- Validate EXIF data for tampering
- Timestamp verification
- Location plausibility check

### Phase 3: Cloud-Based ML Model
- Image classification (TensorFlow Lite / Firebase ML)
- Object detection for asset verification
- Anomaly detection for fraud patterns
- Integration options:
  - Firebase ML Kit
  - Custom TensorFlow model
  - Azure Cognitive Services
  - AWS Rekognition

### Phase 4: Advanced Features
- Face detection (ensure beneficiary is present)
- OCR for invoices/receipts
- Video analysis for authenticity
- Behavioral pattern analysis
