import OCRCore
import SwiftData
import SwiftUI
import UIKit

/// History tab: every saved scan, newest first, with detail navigation and
/// swipe-to-delete.
struct HistoryView: View {
    @Query(sort: \ScanRecord.timestamp, order: .reverse) private var records: [ScanRecord]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "No Scans Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Photos you analyze in the Scan tab are saved here, on this device only.")
                    )
                } else {
                    List {
                        ForEach(records) { record in
                            NavigationLink(value: record) {
                                HistoryRow(record: record)
                            }
                        }
                        .onDelete(perform: deleteRecords)
                    }
                }
            }
            .navigationDestination(for: ScanRecord.self) { record in
                HistoryDetailView(record: record)
            }
            .navigationTitle("History")
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets where records.indices.contains(index) {
            modelContext.delete(records[index])
        }
        // Persist the deletion immediately so it cannot be resurrected by an
        // unflushed context if the app is killed right after the swipe.
        try? modelContext.save()
    }
}

/// One list row: thumbnail, top class, risk badge, and relative timestamp.
private struct HistoryRow: View {
    let record: ScanRecord

    var body: some View {
        HStack(spacing: Theme.spacingM) {
            thumbnail
            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Text(record.topClassName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                HStack(spacing: Theme.spacingS) {
                    RiskBadge(level: record.riskLevel)
                    if record.isDemoResult {
                        DemoBadge()
                    }
                    Text(record.timestamp, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, Theme.spacingXS)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = record.thumbnailData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 12))
                .accessibilityHidden(true)
        } else {
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
                .background(.quaternary, in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
        }
    }
}

/// Detail screen for one saved scan: larger image, confidence, risk tier,
/// model version, and the absolute scan date.
private struct HistoryDetailView: View {
    let record: ScanRecord

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacingL) {
                if record.isDemoResult {
                    demoNotice
                }

                scanImage

                GlassCard {
                    VStack(alignment: .leading, spacing: Theme.spacingM) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(record.topClassName)
                                .font(.title3.bold())
                            Spacer(minLength: Theme.spacingS)
                            if record.isDemoResult {
                                DemoBadge()
                            }
                            RiskBadge(level: record.riskLevel)
                        }
                        LabeledContent("Confidence") {
                            Text(record.probability, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                        }
                        LabeledContent("Model") {
                            Text(record.isDemoResult ? "Demo (\(record.modelVersion))" : record.modelVersion)
                        }
                        LabeledContent("Scanned") {
                            Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                }

                GlassCard {
                    Label {
                        Text(MedicalDisclaimer.full)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Scan Detail")
        .toolbarTitleDisplayMode(.inline)
    }

    /// Clear notice that this saved scan came from the demo stand-in
    /// classifier, so an old mock record can never read as real analysis —
    /// even in a later build that ships a trained model.
    private var demoNotice: some View {
        Label {
            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Text("Demo result")
                    .font(.subheadline.weight(.semibold))
                Text("This scan was made without a trained model. Its scores are generated placeholders and carry no medical meaning.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "testtube.2")
                .foregroundStyle(.orange)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.15), in: .rect(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(.orange.opacity(0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var scanImage: some View {
        if let data = record.thumbnailData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                .accessibilityLabel("Saved scan photo")
        } else {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 160)
                .background(.quaternary, in: .rect(cornerRadius: Theme.cornerRadius))
                .accessibilityLabel("No photo saved for this scan")
        }
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    if let container = try? ModelContainer(for: ScanRecord.self, configurations: configuration) {
        let _ = insertSampleRecords(into: container)
        HistoryView()
            .modelContainer(container)
    }
}

/// Seeds the in-memory preview container with a spread of risk tiers.
private func insertSampleRecords(into container: ModelContainer) {
    let context = container.mainContext
    context.insert(ScanRecord(
        timestamp: .now.addingTimeInterval(-3_600),
        topClassID: "healthy",
        topClassName: "No visible lesion",
        riskLevel: .low,
        probability: 0.82,
        modelVersion: "mock-0.0.0",
        thumbnailData: makeSampleThumbnailData(color: .systemTeal)
    ))
    context.insert(ScanRecord(
        timestamp: .now.addingTimeInterval(-86_400 * 2),
        topClassID: "leukoplakia",
        topClassName: "Leukoplakia",
        riskLevel: .moderate,
        probability: 0.47,
        modelVersion: "mock-0.0.0",
        thumbnailData: nil
    ))
    context.insert(ScanRecord(
        timestamp: .now.addingTimeInterval(-86_400 * 9),
        topClassID: "erythroplakia",
        topClassName: "Erythroplakia",
        riskLevel: .high,
        probability: 0.61,
        modelVersion: "mock-0.0.0",
        thumbnailData: makeSampleThumbnailData(color: .systemRed)
    ))
}

/// Renders a flat-color JPEG stand-in thumbnail for preview records.
private func makeSampleThumbnailData(color: UIColor) -> Data? {
    let size = CGSize(width: 240, height: 240)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.jpegData(withCompressionQuality: 0.8) { context in
        color.withAlphaComponent(0.7).setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}
