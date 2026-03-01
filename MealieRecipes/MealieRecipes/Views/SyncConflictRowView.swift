import SwiftUI

struct SyncConflictRowView: View {
    let title: String
    let localValue: String
    let serverValue: String
    @Binding var useLocal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            HStack(alignment: .center, spacing: 16) {
                // Lokal-Wert
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringProvider.localized("local_value"))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    valueView(for: localValue, highlight: useLocal)
                }

                Spacer()

                // Toggle
                Toggle(isOn: $useLocal) {
                    Text("")
                }
                .labelsHidden()
                .frame(width: 50)
                .padding(.horizontal)

                Spacer()

                // Server-Wert
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringProvider.localized("server_value"))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    valueView(for: serverValue, highlight: !useLocal)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func valueView(for value: String, highlight: Bool) -> some View {
        if value == "largecircle.fill.circle" || value == "circle" {
            Image(systemName: value)
                .font(.system(size: 20))
                .foregroundColor(highlight ? .green : .primary)
        } else {
            Text(value)
                .font(.body)
                .foregroundColor(highlight ? .green : .primary)
        }
    }
}

extension SyncConflictRowView {
    static func symbolForCheckmark(_ checked: Bool) -> String {
        return checked ? "largecircle.fill.circle" : "circle"
    }
}
