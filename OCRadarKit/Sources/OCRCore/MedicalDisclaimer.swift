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
/// - ``noConfidentMatch`` and its three compact forms — everywhere a category
///   name would have gone, when the comparison did not clear the model's
///   confidence threshold.
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

    // MARK: - No confident match

    /// The full statement shown when the closest reference category did not
    /// reach the model's confidence threshold.
    ///
    /// # Three things have to be true of this at once
    ///
    /// **It must not read as reassurance.** "Nothing found" is a rule-out, and
    /// ruling out is the one thing ``full`` promises the app never does. A
    /// person who reads this as "the app checked and I'm fine" has been given
    /// a clearance by a screen that was trying to admit it had nothing to say.
    ///
    /// **It must not read as alarm.** The mirror-image failure is a reader who
    /// concludes that their photo was *too unusual to classify* — that they
    /// have something so far outside the reference set it broke the app. The
    /// ordinary causes are lighting, focus and angle, and saying so is what
    /// keeps the state boring.
    ///
    /// **It must locate the failure in the comparison, not in the person.**
    /// The subject of these sentences is the comparison and the photograph.
    /// Nothing here is a statement about the reader's mouth, because a failed
    /// comparison contains no information about the reader's mouth.
    ///
    /// The last paragraph is the one that matters most, and it is deliberately
    /// the same advice the app gives after a *successful* comparison: what to
    /// do about a thing that worries you does not depend on what this app
    /// managed to say about it.
    ///
    /// Rendered in a card that does not truncate. Paragraph breaks are
    /// load-bearing.
    public static let noConfidentMatch = """
        This photo didn't look clearly like any of the reference categories, \
        so OCRadar isn't naming one.

        That is not a finding. It doesn't mean nothing is there, and it \
        doesn't mean anything is — it means this comparison couldn't be made \
        with confidence. Lighting, focus and angle are the usual reasons, and \
        the reference categories don't cover everything.

        If something in your mouth concerns you, have it looked at. That was \
        true before this screen and it's true now.
        """

    /// The hero label on a result sheet, in the slot ``"visual similarity"``
    /// occupies for a normal result.
    ///
    /// Lowercase for the same reason its sibling is: the slot sits directly
    /// under the hero numeral and is read as the second half of a phrase the
    /// numeral starts. There is no numeral in this state — the sheet shows an
    /// em dash — so these words carry the slot alone.
    public static let noConfidentMatchTitle = "no confident match"

    /// The compact title for rows and list surfaces, where a category name
    /// would otherwise sit: Home's recent-scan hero, Home's rows, History's
    /// rows.
    ///
    /// Sentence case, unlike ``noConfidentMatchTitle``, because in those
    /// surfaces it is a title in its own right rather than the tail of a
    /// phrase.
    public static let noConfidentMatchRowTitle = "No confident match"

    /// What replaces the next-step tier when there is no category to carry one.
    ///
    /// A row whose guidance slot is *blank* where every other row carries an
    /// action reads as "nothing to do here", which is the reassurance this
    /// state must never give. So the slot keeps an action, and the action is
    /// the one that does not depend on the comparison having worked. Phrased
    /// as guidance in the same register as `RiskLevel.displayLabel`, and for
    /// the same reason — it says what to do, never how bad anything is.
    public static let noConfidentMatchNextStep = "Ask someone if it concerns you"
}
