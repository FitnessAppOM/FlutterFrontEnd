# Frontend UI Page Map (Flutter)

Generated: 2026-04-05
Scope: `taqaproject/lib` frontend screens/pages/navigation (including key modal surfaces)

## 1) High-Level Navigation Flow

`MaterialApp` in `lib/main.dart`
- Route `/` -> `BootGate`
- Route `/daily-journal` -> `DailyJournalPage`

Startup flow
- `BootGate` -> `WelcomePage` when no valid session
- `BootGate` -> `MainLayout` (or Diet tab) when session + onboarding complete
- `BootGate` -> `DailyJournalPage` when opened from journal notification
- `BootGate` -> `QuestionnairePage` / `ExpertQuestionnairePage` when onboarding incomplete

Auth/onboarding flow
- `WelcomePage` -> `LoginPage` / `SignupPage`
- `SignupPage` -> `EmailVerificationPage` -> `VerificationSuccessPage` -> questionnaire (`QuestionnairePage` or `ExpertQuestionnairePage`)
- `LoginPage` -> `MainLayout` or questionnaire pages
- Password reset: `ForgotPasswordPage` -> `VerifyResetCodePage` -> `ResetPasswordPage` -> `LoginPage`
- Recovery: `AccountRestorePage` -> `MainLayout` or questionnaire pages

Main app shell
- `MainLayout` tabs:
  - Tab 0: `DashboardPage`
  - Tab 1: `TrainPage`
  - Tab 2: `DietPage`
  - Tab 3: `CommunityPage`
  - Tab 4: `ProfilePage`

## 2) Full Page/Screen Inventory

## App Entry + Shell

| Page/Class | File | Reached From |
|---|---|---|
| `BootGate` | `lib/screens/splash/boot_gate.dart` | App route `/` |
| `WelcomePage` | `lib/screens/welcome.dart` | `BootGate`, logout/reset/account-restore exits |
| `MainLayout` | `lib/main/main_layout.dart` | Login/signup/restore success, boot gate, notification nav |
| `DailyJournalPage` | `lib/screens/daily_journal.dart` | Route `/daily-journal`, dashboard tile, notification flows |

## Auth + Account

| Page/Class | File | Reached From |
|---|---|---|
| `LoginPage` | `lib/auth/login.dart` | `WelcomePage`, verification success, reset-password completion |
| `SignupPage` | `lib/auth/signup.dart` | `WelcomePage` |
| `EmailVerificationPage` | `lib/auth/email_verification_page.dart` | `SignupPage`, unverified login case |
| `VerificationSuccessPage` | `lib/auth/verification_success_page.dart` | `EmailVerificationPage` |
| `QuestionnairePage` | `lib/auth/questionnaire.dart` | Login/signup/boot/welcome/verification/account-restore paths |
| `ExpertQuestionnairePage` | `lib/auth/expert_questionnaire.dart` | Login/signup/boot/welcome/verification/settings/news/account-restore paths |
| `ExpertSubmissionSuccessPage` | `lib/auth/expert_submission_success.dart` | `ExpertQuestionnairePage` submit success |
| `ForgotPasswordPage` | `lib/screens/ForgetPassword/forgot_password_page.dart` | `LoginPage`, `SettingsPage` |
| `VerifyResetCodePage` | `lib/screens/ForgetPassword/verify_reset_code_page.dart` | `ForgotPasswordPage` |
| `ResetPasswordPage` | `lib/screens/ForgetPassword/reset_password_page.dart` | `VerifyResetCodePage` |
| `AccountRestorePage` | `lib/screens/account_restore_page.dart` | Login 403-deactivated, settings reactivation, unauthorized callback |
| `GeneratingTrainingScreen` | `lib/screens/generating_training_screen.dart` | `QuestionnairePage` after submit |

## Main Tabs

| Page/Class | File | Reached From |
|---|---|---|
| `DashboardPage` | `lib/main/pages/dashboard_page.dart` | `MainLayout` tab 0 |
| `TrainPage` | `lib/main/pages/train_page.dart` | `MainLayout` tab 1 |
| `DietPage` | `lib/main/pages/diet_page.dart` | `MainLayout` tab 2 |
| `CommunityPage` | `lib/main/pages/community_page.dart` | `MainLayout` tab 3 |
| `ProfilePage` | `lib/main/pages/profile_page.dart` | `MainLayout` tab 4 |

## Profile + Settings + Profile Editing

| Page/Class | File | Reached From |
|---|---|---|
| `SettingsPage` | `lib/screens/settings_page.dart` | Profile header settings icon |
| `EditProfilePage` | `lib/screens/edit_profile_page.dart` | `ProfilePage` |
| `UpdatingPlanScreen` | `lib/screens/updating_plan_screen.dart` | `EditProfilePage` when training-related fields change |
| `UpdatingDietScreen` | `lib/screens/updating_diet_screen.dart` | `EditProfilePage` when goal/diet fields change |
| `_AffiliationSelectionPage` (internal) | `lib/screens/edit_profile_page.dart` | Pushed from `EditProfilePage` |
| `_AffiliationSelectionPage` (internal) | `lib/widgets/questionnaire/expert_questionnaire_form.dart` | Pushed from expert questionnaire form |
| `_CertificateSelectionPage` (internal) | `lib/widgets/questionnaire/expert_questionnaire_form.dart` | Pushed from expert questionnaire form |

## Dashboard-Linked Detail Screens

| Page/Class | File | Reached From |
|---|---|---|
| `AnnouncementsPage` | `lib/screens/announcements_page.dart` | Dashboard announcements action |
| `ArticlePage` | `lib/screens/article_page.dart` | `AnnouncementsPage` via `NewsTagActions` |
| `TaqaScoreDetailPage` | `lib/screens/taqa_score_detail_page.dart` | Dashboard TAQA score widget |
| `StepsDetailPage` | `lib/screens/steps_detail_page.dart` | Dashboard steps card |
| `SleepDetailPage` | `lib/screens/sleep_detail_page.dart` | Dashboard sleep cards, Whoop insights sleep card |
| `CaloriesDetailPage` | `lib/screens/calories_detail_page.dart` | Dashboard calories card |
| `WhoopInsightsPage` | `lib/screens/whoop_insights_page.dart` | Dashboard Whoop insights action |
| `WhoopRecoveryDetailPage` | `lib/screens/whoop_recovery_detail_page.dart` | Dashboard and `WhoopInsightsPage` |
| `WhoopCycleDetailPage` | `lib/screens/whoop_cycle_detail_page.dart` | Dashboard and `WhoopInsightsPage` |
| `WhoopBodyDetailPage` | `lib/screens/whoop_body_detail_page.dart` | Dashboard and `WhoopInsightsPage` |
| `FitbitInsightsPage` | `lib/screens/fitbit_insights_page.dart` | Dashboard Fitbit insights action |
| `StravaDetailPage` | `lib/screens/strava_detail_page.dart` | Dashboard Strava card (`activities` mode) |
| `WhoopTestPage` | `lib/screens/whoop_test_page.dart` | Currently not linked from active UI flow |

## Training + Cardio Detail Screens

| Page/Class | File | Reached From |
|---|---|---|
| `CardioTab` (embedded view) | `lib/screens/cardio/cardio_tab.dart` | Embedded inside `TrainPage` cardio tab |
| `TrainingHistoryPage` | `lib/screens/training/training_history_page.dart` | `TrainPage` history action |
| `TrainingHistoryDayDetailPage` | `lib/screens/training/training_history_day_detail_page.dart` | `TrainingHistoryPage` day item tap |
| `CardioHistoryPage` | `lib/screens/cardio/cardio_history_page.dart` | `CardioTab` history button |
| `CardioHistoryDetailPage` | `lib/screens/cardio/cardio_history_detail_page.dart` | `CardioHistoryPage` session tap |
| `OtherModelsPage` | `lib/screens/training/other_models/other_models_page.dart` | From `CardioAchievementSheet` |
| `ModelAPage` | `lib/screens/training/other_models/model_a_page.dart` | Inside `OtherModelsPage` pager |
| `ModelBPage` | `lib/screens/training/other_models/model_b_page.dart` | Inside `OtherModelsPage` pager |
| `ModelCPage` | `lib/screens/training/other_models/model_c_page.dart` | Inside `OtherModelsPage` pager |

## 3) Key Modal/Sheet/Dialog UI Surfaces (Designer-Relevant)

These are not full routes, but they are major designed UI surfaces in this app.

| Surface | File | Triggered From |
|---|---|---|
| `ExerciseSessionSheet` | `lib/widgets/training/exercise_session_sheet.dart` | `TrainPage` start workout flow |
| `ReplaceExerciseSheet` | `lib/widgets/training/replace_exercise_sheet.dart` | `TrainPage` replace exercise |
| `TrainingDayCompleteSheet` | `lib/widgets/training/training_day_complete_sheet.dart` | `TrainPage` completion flow |
| `CardioAchievementSheet` | `lib/screens/training/cardio_achievement_sheet.dart` | Workout completion + cardio history detail share action |
| `ExerciseFeedbackSheet` | `lib/widgets/training/exercise_feedback_sheet.dart` | From `ExerciseSessionSheet` |
| `ExerciseInstructionDialog` | `lib/widgets/training/exercise_instruction_dialog.dart` | From `ExerciseSessionSheet` |
| `DietLoggingOptionsSheet` | `lib/widgets/diet_logging_options_sheet.dart` | `DietPage` add meal action |
| `DietItemSearchSheet` | `lib/widgets/diet_item_search_sheet.dart` | `DietPage` logging flow |
| `DietManualEntrySheet` | `lib/widgets/diet_manual_entry_sheet.dart` | `DietPage` logging flow |
| `DietPhotoEntrySheet` | `lib/widgets/diet_photo_entry_sheet.dart` | `DietPage` logging flow |
| `DietFavoritesSheet` | `lib/widgets/diet_favorites_sheet.dart` | `DietPage` favorites action |
| `DietFoodsMasterPickerSheet` | `lib/widgets/diet_foods_master_picker_sheet.dart` | From `DietManualEntrySheet` |
| `WaterIntakeSheet` | `lib/widgets/dashboard/water_intake_sheet.dart` | `DashboardPage` water card |
| `BodyMeasurementsSheet` | `lib/widgets/dashboard/body_measurements_sheet.dart` | `DashboardPage` body card |
| `HealthRecoveryLoadSheet` | `lib/widgets/dashboard/health_recovery_load_sheet.dart` | `DashboardPage` recovery/load card |
| `FitbitDailyActivitySheet` | `lib/widgets/dashboard/fitbit_daily_activity_sheet.dart` | `DashboardPage`, `FitbitInsightsPage` |
| `FitbitHeartSheet` | `lib/widgets/dashboard/fitbit_heart_sheet.dart` | `DashboardPage`, `FitbitInsightsPage` |
| `FitbitSleepSheet` | `lib/widgets/dashboard/fitbit_sleep_sheet.dart` | `DashboardPage`, `FitbitInsightsPage` |
| `FitbitVitalsSheet` | `lib/widgets/dashboard/fitbit_vitals_sheet.dart` | `FitbitInsightsPage` |
| `FitbitBodySheet` | `lib/widgets/dashboard/fitbit_body_sheet.dart` | `DashboardPage`, `FitbitInsightsPage` |
| `WidgetLibrarySheet` | `lib/widgets/dashboard/widget_library_sheet.dart` | `DashboardPage` edit-mode customization |
| `ScreeningFormSheet` | `lib/widgets/screening/screening_form_sheet.dart` | `DailyJournalPage` screening due banner |
| `ReleaseNotesDialog` | `lib/widgets/release_notes_notice.dart` | Dashboard release-notes notice |

## 4) Notes for Design Planning

- `CommunityPage` is currently a placeholder view.
- `WhoopTestPage` exists but currently has no active navigation entry in the UI.
- `StravaDetailPage` has a `create` mode in code, but current UI links only open `activities` mode.
- For visual audits, include both routed pages and major sheets/dialogs above; many critical interactions happen in bottom sheets rather than full-page transitions.
