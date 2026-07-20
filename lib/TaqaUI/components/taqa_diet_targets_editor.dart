/// Shared TaqaUI Diet Targets editor.
///
/// The editor is implemented in the main Diet module so it can retain its
/// localization and target-value interactions. Expert flows import it through
/// this TaqaUI entry point to use the exact same editor.
export '../../main/pages/diet_page.dart'
    show TaqaDietTargetsEditorPage, TaqaDietTargetsEditorResult;
