import SwiftUI

struct DatePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDate: Date
    let onSelect: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    LocalizedStringProvider.localized("select_date"),
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                .onChange(of: selectedDate) { oldValue, newValue in
                    // Automatisch zur ausgewählten Woche springen
                    onSelect()
                }
                
                Spacer()
                
                Button {
                    onSelect()
                } label: {
                    Text(LocalizedStringProvider.localized("select"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle(LocalizedStringProvider.localized("select_date"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringProvider.localized("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringProvider.localized("done")) {
                        onSelect()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
