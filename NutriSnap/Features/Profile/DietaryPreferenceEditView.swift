import SwiftUI

struct DietaryPreferenceEditView: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let options: [String]
    
    @Binding var selectedOptions: [String]
    let onSave: () -> Void
    
    // Internal state to hold temporary selections before hitting "Save"
    @State private var tempSelections: Set<String> = []
    
    let brandGreen = Color(red: 0.1, green: 0.8, blue: 0.5)
    
    var body: some View {
        NavigationView {
            List {
                ForEach(options.filter { $0 != "Select" }, id: \.self) { option in
                    Button(action: {
                        if tempSelections.contains(option) {
                            tempSelections.remove(option)
                        } else {
                            tempSelections.insert(option)
                        }
                    }) {
                        HStack {
                            Text(option)
                                .foregroundColor(.primary)
                            Spacer()
                            if tempSelections.contains(option) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(brandGreen)
                                    .fontWeight(.bold)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        selectedOptions = Array(tempSelections)
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(brandGreen)
                }
            }
            .onAppear {
                tempSelections = Set(selectedOptions)
            }
        }
    }
}
