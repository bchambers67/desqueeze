import DesqueezeCore
import SwiftUI

/// One photo and one factor: the editor the extensions show.
///
/// The share sheet and the Photos editing sheet are small, short-lived hosts.
/// They get the slider and a live picture, not the whole app.
@MainActor @Observable
final class QuickEditModel {
    var factor: Double = 2.0
    private(set) var picture: CGImage?
    private(set) var failure: String?
    private(set) var isWorking = false

    private var source: Data?
    private let renderer = CoreImageRenderer()

    var hasPhoto: Bool { source != nil }

    func load(_ data: Data) async {
        source = data
        failure = nil
        do {
            // Rendered once, as shot. The view shapes it to the factor, so the
            // slider never waits on a render.
            picture = try await renderer.preview(of: data, squeeze: Squeeze(factor: 1), longestEdge: 1800).image
        } catch {
            source = nil
            failure = error.localizedDescription
        }
    }

    func fail(_ message: String) { failure = message }

    struct NothingLoaded: Error {}

    /// The corrected photo at full size, as JPEG, with capture metadata kept.
    func export() async throws -> Data {
        guard let source else { throw NothingLoaded() }
        isWorking = true
        defer { isWorking = false }
        let squeeze = Squeeze(factor: factor)
        let size = squeeze.outputSize(for: try await renderer.size(of: source))
        let jpeg = try await renderer.export(source, squeeze: squeeze, matte: nil)
        return CaptureMetadata.carry(from: source, onto: jpeg, size: size)
    }
}

struct QuickEditor: View {
    @Bindable var model: QuickEditModel
    /// A title bar with Cancel and an action, for hosts that supply none.
    var actionTitle: String?
    var cancel: (() -> Void)?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if let actionTitle, let cancel, let action {
                HStack {
                    Button("Cancel", action: cancel)
                    Spacer()
                    Button(action: action) {
                        if model.isWorking {
                            ProgressView().tint(Brand.ground)
                        } else {
                            Text(actionTitle).fontWeight(.semibold).foregroundStyle(Brand.ground)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.accent)
                    .disabled(!model.hasPhoto || model.isWorking)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            ZStack {
                if let picture = model.picture {
                    let shot = CGFloat(picture.width) / CGFloat(max(picture.height, 1))
                    Image(decorative: picture, scale: 1)
                        .resizable()
                        .aspectRatio(shot * model.factor, contentMode: .fit)
                        .padding(16)
                } else if let failure = model.failure {
                    Text(failure)
                        .font(Brand.sans(14))
                        .foregroundStyle(Brand.error)
                        .multilineTextAlignment(.center)
                        .padding(24)
                } else {
                    ProgressView().tint(Brand.accent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let failure = model.failure, model.picture != nil {
                Text(failure)
                    .font(Brand.sans(13))
                    .foregroundStyle(Brand.error)
                    .padding(.horizontal, 20)
            }

            FactorSlider(factor: $model.factor)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)
        }
        .background(Brand.ground.ignoresSafeArea())
        .foregroundStyle(Brand.primary)
        .tint(Brand.primary)
        .preferredColorScheme(.dark)
    }
}
