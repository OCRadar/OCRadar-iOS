import Foundation

/// Canonical disclaimer copy. Shown at first launch, with every result, and in
/// Settings — always sourced from here so the wording stays consistent.
public enum MedicalDisclaimer {
    public static let short = "Not a medical device — results are informational only."

    public static let full = """
        OCRadar is a screening aid and does not provide medical advice, \
        diagnosis, or treatment. Results come from an on-device image model \
        and can be wrong in either direction. Always consult a dentist or \
        physician about any lesion, discoloration, or symptom that concerns \
        you, regardless of what this app reports.
        """
}
