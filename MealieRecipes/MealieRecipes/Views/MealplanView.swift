import SwiftUI

// 🔧 Lokale Logging-Hilfe (falls globale nicht gefunden wird)
private func logMessage(_ message: String) {
    Swift.print(message)
    
    if AppSettings.shared.enableLogging {
        LogManager.shared.logPrint(message)
    }
}

private func logMessage(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
    
    if AppSettings.shared.enableLogging {
        LogManager.shared.logPrint(output)
    }
}

struct MealplanView: View {
    @StateObject private var viewModel = MealplanViewModel()
    @State private var showAddMealSheet = false
    @State private var showDatePicker = false
    @State private var selectedDate = Date()
    @State private var currentWeekStart: Date = Self.defaultStartOfWeek()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                calendarHeader
                    .padding(.vertical, 12)
                    .background(Color(.systemGroupedBackground))

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else if filteredEntriesByDay.isEmpty {
                            emptyStateView
                        } else {
                            let sortedKeys = filteredEntriesByDay.keys.sorted()
                            ForEach(sortedKeys, id: \.self) { date in
                                daySection(for: date)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                .refreshable {
                    logMessage("🔄 Pull-to-Refresh ausgelöst")
                    await viewModel.fetchMealplanAsync()
                }
            }
            .navigationTitle(LocalizedStringProvider.localized("meal_plan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // "Heute" Button
                    if !isCurrentWeek {
                        Button {
                            withAnimation {
                                currentWeekStart = Self.defaultStartOfWeek()
                            }
                        } label: {
                            Text(LocalizedStringProvider.localized("today"))
                                .font(.subheadline)
                        }
                    }
                    
                    // Kalender-Icon für Datumswahl
                    Button {
                        selectedDate = currentWeekStart
                        showDatePicker = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.title3)
                    }
                    
                    Button {
                        showAddMealSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .onAppear {
                logMessage("👁️ MealplanView erscheint - Lade Daten")
                viewModel.fetchMealplan()
            }
            .sheet(isPresented: $showAddMealSheet) {
                AddMealEntryView { date, slot, recipeId, note in
                    Task {
                        do {
                            logMessage("🔵 MealplanView: onAdd-Closure aufgerufen")
                            logMessage("   Rezept-ID: \(recipeId ?? "nil")")
                            
                            try await APIService.shared.addMealEntry(
                                date: date,
                                slot: slot,
                                recipeId: recipeId,
                                note: note
                            )
                            
                            logMessage("✅ Mahlzeit erfolgreich eingeplant, lade Mealplan neu...")
                            await viewModel.fetchMealplanAsync()
                        } catch {
                            logMessage("❌ Fehler beim Hinzufügen: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(
                    selectedDate: $selectedDate,
                    onSelect: {
                        withAnimation {
                            currentWeekStart = Calendar.current.startOfWeek(for: selectedDate)
                        }
                        showDatePicker = false
                    }
                )
            }
        }
    }

    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
                .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text(LocalizedStringProvider.localized("no_meals"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                // Prüfe ob es Einträge in anderen Wochen gibt
                if hasEntriesInOtherWeeks {
                    VStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                            Text(LocalizedStringProvider.localized("entries_in_other_weeks"))
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal)
                        
                        // Gruppierte Anzeige der verfügbaren Wochen
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStringProvider.localized("available_weeks"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(getAvailableWeeks(), id: \.self) { weekStart in
                                weekButton(for: weekStart)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground).opacity(0.5))
                        .cornerRadius(12)
                    }
                }
            }
            
            Button {
                showAddMealSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(LocalizedStringProvider.localized("plan_meal"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Calendar Header
    
    private var calendarHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if let previousWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) {
                            currentWeekStart = Calendar.current.startOfWeek(for: previousWeek)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }

                Spacer()

                VStack(spacing: 1) {
                    Text(weekHeaderText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if isCurrentWeek {
                        Text(LocalizedStringProvider.localized("current_week"))
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                    }
                }
                .multilineTextAlignment(.center)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) {
                            currentWeekStart = Calendar.current.startOfWeek(for: nextWeek)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            
            // Tagesübersicht der Woche (kompakter)
            if !filteredEntriesByDay.isEmpty {
                weekDayIndicators
                    .padding(.top, 2)
            }
        }
    }
    
    // MARK: - Week Day Indicators
    
    private var weekDayIndicators: some View {
        HStack(spacing: 4) {
            ForEach(0..<7) { dayOffset in
                if let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: currentWeekStart) {
                    let hasEntries = filteredEntriesByDay[Calendar.current.startOfDay(for: date)] != nil
                    let isToday = Calendar.current.isDateInToday(date)
                    
                    VStack(spacing: 3) {
                        Text(dayOfWeekLetter(for: date))
                            .font(.system(size: 11, weight: isToday ? .bold : .regular))
                            .foregroundColor(isToday ? .accentColor : .secondary)
                        
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 10))
                            .foregroundColor(isToday ? .accentColor : .secondary)
                        
                        Circle()
                            .fill(hasEntries ? Color.accentColor : Color.clear)
                            .frame(width: 4, height: 4)
                            .overlay(
                                Circle()
                                    .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 1)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Day Section
    
    @ViewBuilder
    private func daySection(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tag-Header
            HStack {
                Text(viewModel.localizedDate(date))
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                if Calendar.current.isDateInToday(date) {
                    Text(LocalizedStringProvider.localized("today"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .cornerRadius(6)
                }
            }
            
            // Einträge für diesen Tag
            VStack(spacing: 8) {
                ForEach(filteredEntriesByDay[date] ?? []) { entry in
                    mealEntryCard(entry)
                }
            }
        }
    }
    
    // MARK: - Meal Entry Card
    
    @ViewBuilder
    private func mealEntryCard(_ entry: MealplanEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Slot-Emoji mit Hintergrund
            Text(slotEmoji(entry.entryType))
                .font(.title2)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                // Slot-Name
                Text(LocalizedStringProvider.localized(entry.entryType))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                // Rezept/Titel
                if let recipe = entry.recipe {
                    if let id = UUID(uuidString: recipe.id) {
                        NavigationLink(destination: RecipeDetailView(recipeId: id)) {
                            Text(recipe.name)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }
                    } else {
                        Text(recipe.name)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                } else if let title = entry.title {
                    HStack(spacing: 4) {
                        Image(systemName: "text.quote")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(title)
                            .font(.body)
                            .italic()
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                } else if let text = entry.text {
                    HStack(spacing: 4) {
                        Image(systemName: "text.quote")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(text)
                            .font(.body)
                            .italic()
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                } else {
                    Text("🛑 Unknown Entry")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            Button(role: .destructive) {
                withAnimation {
                    viewModel.removeMeal(entry)
                }
            } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.title3)
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onAppear {
            logMessage("🎨 Zeige Mealplan-Eintrag:")
            logMessage("   ID: \(entry.id)")
            logMessage("   Datum: \(entry.date)")
            logMessage("   Typ: \(entry.entryType)")
            logMessage("   Recipe: \(entry.recipe?.name ?? "nil")")
            logMessage("   Title: \(entry.title ?? "nil")")
            logMessage("   Text: \(entry.text ?? "nil")")
        }
    }

    var filteredEntriesByDay: [Date: [MealplanEntry]] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: currentWeekStart)
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfDay)!
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: endOfWeek)!
        
        let filtered = viewModel.entriesByDay.filter { date, entries in
            let isInRange = date >= startOfDay && date < endOfDay
            return isInRange
        }
        
        return filtered
    }
    
    // Separate computed property für bessere Performance und Vermeidung von Race Conditions
    var hasEntriesInOtherWeeks: Bool {
        return !getAvailableWeeks().isEmpty
    }

    var weekHeaderText: String {
        let calendar = Calendar.current
        let weekNumber = currentWeekStart.calendarWeekNumber()
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: currentWeekStart)!

        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        let weekAbbreviation = LocalizedStringProvider.localized("week_abbreviation")
        return "\(weekAbbreviation) \(weekNumber) (\(formatter.string(from: currentWeekStart)) – \(formatter.string(from: endOfWeek)))"
    }

    // MARK: - Helper Functions
    
    private var isCurrentWeek: Bool {
        let calendar = Calendar.current
        let currentWeekStart = calendar.startOfWeek(for: Date())
        return calendar.isDate(currentWeekStart, inSameDayAs: self.currentWeekStart)
    }
    
    private func weekButton(for weekStart: Date) -> some View {
        WeekButtonView(
            weekStart: weekStart,
            count: getEntriesCount(for: weekStart),
            onTap: {
                withAnimation {
                    currentWeekStart = weekStart
                }
            }
        )
    }
    
    // MARK: - Week Button View
    
    private struct WeekButtonView: View {
        let weekStart: Date
        let count: Int
        let onTap: () -> Void
        
        private var weekEnd: Date {
            Calendar.current.date(byAdding: .day, value: 6, to: weekStart)!
        }
        
        private var dateRangeText: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM"
            return "(\(formatter.string(from: weekStart)) – \(formatter.string(from: weekEnd)))"
        }
        
        private var entriesText: String {
            count == 1 
                ? LocalizedStringProvider.localized("entry_singular")
                : LocalizedStringProvider.localized("entries_plural")
        }
        
        var body: some View {
            Button(action: onTap) {
                HStack {
                    Text("\(LocalizedStringProvider.localized("week_abbreviation")) \(weekStart.calendarWeekNumber())")
                        .fontWeight(.semibold)
                    Text(dateRangeText)
                        .font(.caption)
                    
                    Spacer()
                    
                    Text("\(count) \(entriesText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func dayOfWeekLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppSettings.shared.selectedLanguage)
        formatter.dateFormat = "EEEEE" // Einzelbuchstabe
        return formatter.string(from: date).uppercased()
    }
    
    private func getAvailableWeeks() -> [Date] {
        let calendar = Calendar.current
        var weeks: Set<Date> = []
        
        for date in viewModel.entriesByDay.keys {
            let weekStart = calendar.startOfWeek(for: date)
            // Nur Wochen hinzufügen, die NICHT die aktuelle Woche sind
            if !calendar.isDate(weekStart, inSameDayAs: currentWeekStart) {
                weeks.insert(weekStart)
            }
        }
        
        return weeks.sorted()
    }
    
    private func getEntriesCount(for weekStart: Date) -> Int {
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        
        var count = 0
        for (date, entries) in viewModel.entriesByDay {
            if date >= weekStart && date <= weekEnd {
                count += entries.count
            }
        }
        return count
    }

    func slotEmoji(_ slot: String) -> String {
        switch slot.lowercased() {
        case "breakfast": return "🍳"
        case "lunch":     return "🥪"
        case "dinner":    return "🍽"
        default:          return "🍴"
        }
    }

    private static func defaultStartOfWeek() -> Date {
        Calendar.current.startOfWeek(for: Date())
    }
}
