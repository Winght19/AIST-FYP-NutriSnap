//
//  ContentView.swift
//  NutriSnap
//
//  Created by Tsz Wing on 13/1/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    // Query the FoodLog, not Item
    @Query private var logs: [FoodLog]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(logs) { log in
                    HStack {
                        Text(log.foodName)
                        Spacer()
                        Text("\(Int(log.Calories)) kcal")
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            // Create a fake food entry to test the database
            let newFood = FoodLog(name: "Test Apple", calories: 52, protein: 0.3, carbs: 14)
            modelContext.insert(newFood)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(logs[index])
            }
        }
    }
}
