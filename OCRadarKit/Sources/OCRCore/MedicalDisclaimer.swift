import Foundation

/// Canonical disclaimer copy — the single source of truth for what this app
/// claims about itself.
///
/// # The position these strings encode
///
/// OCRadar is an **awareness and educational tool**. It helps someone notice
/// something and decide whether to ask a professional about it. It does not
/// screen, detect, diagnose, assess, evaluate, or rule anything in or out. It
/// reports *visual similarity* to reference categories and never states what a
/// lesion is. It is not a medical device and has not been evaluated by any
/// regulator. Only a dentist or physician can examine a lesion.
///
/// Every word the app says about itself has to be consistent with that. These
/// strings are how that consistency is enforced: there is one wording, and it
/// lives here.
///
/// # No screen may paraphrase
///
/// Call sites pass one of these constants **verbatim**. Never rewrite, shorten,
/// truncate, line-limit, or "adapt to fit" any of them, and never write a new
/// disclaimer sentence at a call site. If a surface needs different words, the
/// new wording is added here, reviewed here, and inherited — a paraphrase at a
/// call site is a claim nobody reviewed.
///
/// # Which string goes where
///
/// Each one exists for a different moment, and they are not interchangeable:
///
/// - ``short`` — the compact banner. Home, Settings.
/// - ``full`` — the complete statement. The first-launch gate, the Settings
///   re-read, and any surface with room for all of it.
/// - ``capture`` — before the shutter, where the expectation is set.
/// - ``resultLead`` — beside the result itself, where the consequence is
///   highest.
///
/// # Restraint is part of the design
///
/// The notice belongs at every moment of consequence and nowhere else. A screen
/// that already carries the message in its own words does not also need a
/// banner; a wall of warnings trains people to skip all of them and reads as
/// defensive rather than honest. Adding a surface is a copy decision, not a
/// safety upgrade.
public enum MedicalDisclaimer {
    /// One line for a compact banner. Unambiguous, no hedging.
    public static let short =
        "OCRadar is an awareness tool, not a diagnosis. Only a dentist or physician can examine a lesion."

    /// The complete statement, in plain language.
    ///
    /// Covers, in order: what the app is; that it is not a medical device and
    /// carries no regulatory review; that it does not diagnose, screen for, or
    /// rule out anything, cancer included; what it actually does, and that it
    /// errs in both directions; and what to do regardless of what it says.
    ///
    /// Rendered in a scrolling container, so it is never truncated. Paragraph
    /// breaks are load-bearing — they are what makes it readable rather than a
    /// block of legalese.
    public static let full = """
        OCRadar is an awareness tool. It is here to help you notice something \
        and decide whether to ask a professional about it.

        It is not a medical device. It has not been reviewed or evaluated by \
        the FDA or any other regulator.

        It does not diagnose, screen for, or rule out any condition, including \
        cancer. It compares your photo with reference images and shows you \
        which categories look similar. That is all it does.

        The comparison can be wrong in both directions. It can point at \
        something completely harmless, and it can miss something serious.

        Only a dentist or physician can examine a lesion. Never delay care \
        because of what this app shows you. If something in your mouth \
        concerns you, get it looked at — whatever this app says.
        """

    /// Shown before the user takes a photo, so the expectation is set before
    /// the result exists rather than corrected afterwards.
    public static let capture =
        "This looks for visual similarity to reference photos. It cannot tell you what something is."

    /// Shown immediately beside a result, where the consequence is highest and
    /// a reader is least likely to scroll for context.
    public static let resultLead =
        "A visual comparison, not a diagnosis. Only a dentist or physician can tell you what this is."
}
