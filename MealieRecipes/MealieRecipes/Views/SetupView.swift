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

struct SetupView: View {
    var isInitialSetup: Bool = true
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @AppStorage("isSetupCompleted") private var isSetupCompleted = false
    @State private var shouldRestartSetup = false

    @State private var tempLanguage: String = AppSettings.shared.selectedLanguage
    @State private var tempApiVersion: MealieAPIVersion = AppSettings.shared.apiVersion
    @State private var tempServerURL: String = ""
    @State private var tempToken: String = ""
    @State private var tempHouseholdId: String = "Family"
    @State private var tempShoppingListId: String = ""
    @State private var tempSendOptionalHeaders: Bool = false
    @State private var tempShowRecipeImages: Bool = true
    @State private var tempEnableLogging: Bool = true

    @State private var optionalHeaderKey1: String = ""
    @State private var optionalHeaderValue1: String = ""
    @State private var optionalHeaderKey2: String = ""
    @State private var optionalHeaderValue2: String = ""
    @State private var optionalHeaderKey3: String = ""
    @State private var optionalHeaderValue3: String = ""

    @State private var shoppingLists: [ShoppingList] = []
    @State private var isLoadingShoppingLists = false
    @State private var showResetConfirmation = false
    
    @State private var showLogAlert = false
    @State private var logAlertMessage: String = ""
    
    // Haptic Feedback
    private let hapticNotification = UINotificationFeedbackGenerator()
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    
    // Trigger für UI-Refresh
    @State private var logRefreshTrigger = UUID()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 🎨 Header mit Icon (nur bei Initial Setup)
                    if isInitialSetup {
                        welcomeHeader
                    }
                    
                    // 🔐 Verbindungs-Sektion
                    connectionSection
                    
                    // 🛒 Shopping-Liste
                    shoppingListCardSection
                    
                    // ⚙️ Erweiterte Optionen
                    advancedOptionsSection
                    
                    // 🎨 Personalisierung
                    personalizationSection
                    
                    // 📋 Entwickler-Optionen (nur wenn nicht Initial-Setup)
                    if !isInitialSetup {
                        developerSection
                    }
                    
                    // 💾 Aktions-Buttons
                    actionButtons
                }
                .padding()
                .padding(.bottom, 20)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemGroupedBackground),
                        Color(.systemGroupedBackground).opacity(0.95)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle(isInitialSetup
                             ? LocalizedStringProvider.localized("initial_setup")
                             : LocalizedStringProvider.localized("settings"))
            .navigationBarTitleDisplayMode(.inline)
            .id(tempLanguage)
            .onAppear {
                loadSettings()
                Task { await fetchShoppingLists() }
            }
            .onDisappear {
                LocalizedStringProvider.overrideLanguage = nil
            }
            .alert(LocalizedStringProvider.localized("confirm_reset"), isPresented: $showResetConfirmation) {
                Button(LocalizedStringProvider.localized("cancel"), role: .cancel) {}
                Button(LocalizedStringProvider.localized("reset"), role: .destructive) {
                    hapticNotification.notificationOccurred(.warning)
                    resetAppSettings()
                    isSetupCompleted = false
                    shouldRestartSetup = true
                }
            } message: {
                Text(LocalizedStringProvider.localized("reset_warning"))
            }
            .alert("Logs (letzte 500)", isPresented: $showLogAlert) {
                if logAlertMessage == "Alle Log-Einträge wurden gelöscht." {
                    Button("OK", role: .cancel) { }
                } else {
                    Button("Kopieren", role: .none) {
                        UIPasteboard.general.string = logAlertMessage
                        hapticNotification.notificationOccurred(.success)
                    }
                    Button("Schließen", role: .cancel) { }
                }
            } message: {
                if logAlertMessage == "Alle Log-Einträge wurden gelöscht." {
                    Text(logAlertMessage)
                } else {
                    ScrollView {
                        Text(logAlertMessage.isEmpty ? "Keine Logs vorhanden" : logAlertMessage)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
        .fullScreenCover(isPresented: $shouldRestartSetup) {
            SetupView(isInitialSetup: true)
        }
    }
    
    // MARK: - Welcome Header
    
    private var welcomeHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text(LocalizedStringProvider.localized("initial_setup"))
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Verbinde dich mit deinem Mealie Server")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Connection Section
    
    private var connectionSection: some View {
        SectionCard(
            title: LocalizedStringProvider.localized("connection"),
            icon: "server.rack",
            iconColor: .blue
        ) {
            VStack(spacing: 16) {
                ModernInputField(
                    title: "Server URL",
                    text: $tempServerURL,
                    icon: "link",
                    placeholder: "https://mealie.example.com"
                )
                .keyboardType(.URL)
                .textContentType(.URL)
                
                ModernSecureField(
                    title: "Token",
                    text: $tempToken,
                    icon: "key.fill",
                    placeholder: "Dein API-Token"
                )
                
                ModernInputField(
                    title: "Household",
                    text: $tempHouseholdId,
                    icon: "house.fill",
                    placeholder: "Family"
                )
            }
        }
    }
    
    // MARK: - Shopping List Card Section
    
    private var shoppingListCardSection: some View {
        SectionCard(
            title: LocalizedStringProvider.localized("select_shopping_list"),
            icon: "cart.fill",
            iconColor: .green
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Menu {
                        ForEach(shoppingLists, id: \.id) { list in
                            Button {
                                tempShoppingListId = list.id
                                hapticImpact.impactOccurred()
                            } label: {
                                HStack {
                                    Text(list.name)
                                    if list.id == tempShoppingListId {
                                        Spacer()
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet.circle.fill")
                                .foregroundColor(.green)
                            
                            Text(
                                shoppingLists.first(where: { $0.id == tempShoppingListId })?.name
                                ?? LocalizedStringProvider.localized("no_lists_loaded")
                            )
                            .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    .disabled(shoppingLists.isEmpty)
                    
                    Button {
                        hapticImpact.impactOccurred()
                        Task { await fetchShoppingLists() }
                    } label: {
                        Group {
                            if isLoadingShoppingLists {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .disabled(tempServerURL.isEmpty || tempToken.isEmpty || isLoadingShoppingLists)
                }
                
                if tempShoppingListId.isEmpty && shoppingLists.isEmpty && !tempServerURL.isEmpty && !tempToken.isEmpty {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text(LocalizedStringProvider.localized("no_lists_loaded"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - Advanced Options Section
    
    private var advancedOptionsSection: some View {
        SectionCard(
            title: LocalizedStringProvider.localized("advanced_options"),
            icon: "gearshape.2.fill",
            iconColor: .purple
        ) {
            VStack(spacing: 16) {
                // API Version
                VStack(alignment: .leading, spacing: 8) {
                    Label("Mealie API-Version", systemImage: "server.rack")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("API-Version", selection: $tempApiVersion) {
                        Text("v2.8").tag(MealieAPIVersion.v2_8)
                        Text("v3.x").tag(MealieAPIVersion.v3)
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider()
                
                // Optional Headers Toggle
                ModernToggle(
                    title: LocalizedStringProvider.localized("send_optional_headers"),
                    icon: "doc.text.fill",
                    isOn: $tempSendOptionalHeaders
                )
                
                if tempSendOptionalHeaders {
                    optionalHeadersExpandedSection
                }
            }
        }
    }
    
    private var optionalHeadersExpandedSection: some View {
        VStack(spacing: 12) {
            Divider()
            
            ForEach(1...3, id: \.self) { index in
                HStack(spacing: 12) {
                    ModernInputField(
                        title: "Header \(index) Name",
                        text: binding(forHeaderKey: index),
                        icon: "tag.fill",
                        placeholder: "Name"
                    )
                    
                    ModernInputField(
                        title: "Header \(index) Value",
                        text: binding(forHeaderValue: index),
                        icon: "equal.circle.fill",
                        placeholder: "Wert"
                    )
                }
            }
        }
    }
    
    // MARK: - Personalization Section
    
    private var personalizationSection: some View {
        SectionCard(
            title: LocalizedStringProvider.localized("personalization"),
            icon: "paintbrush.fill",
            iconColor: .pink
        ) {
            VStack(spacing: 16) {
                // Sprache
                languagePickerModern
                
                Divider()
                
                // App-Logo
                logoPickerModern
                
                Divider()
                
                // Rezeptbilder
                ModernToggle(
                    title: LocalizedStringProvider.localized("show_recipe_images"),
                    subtitle: LocalizedStringProvider.localized("show_recipe_images_description"),
                    icon: "photo.fill",
                    isOn: $tempShowRecipeImages
                )
            }
        }
    }
    
    // MARK: - Developer Section
    
    private var developerSection: some View {
        SectionCard(
            title: LocalizedStringProvider.localized("developer"),
            icon: "hammer.fill",
            iconColor: .orange
        ) {
            VStack(spacing: 16) {
                // Logging Toggle
                ModernToggle(
                    title: LocalizedStringProvider.localized("enable_logging"),
                    subtitle: LocalizedStringProvider.localized("enable_logging_description"),
                    icon: "doc.text.fill",
                    isOn: $tempEnableLogging
                )
                
                Divider()
                
                // Log Stats
                logStatsView
                
                // Log Buttons
                HStack(spacing: 12) {
                    Button {
                        hapticImpact.impactOccurred()
                        showLogsPreview()
                    } label: {
                        Label(LocalizedStringProvider.localized("log_show"), systemImage: "eye.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    
                    Button(role: .destructive) {
                        hapticImpact.impactOccurred()
                        clearLogs()
                    } label: {
                        Label(LocalizedStringProvider.localized("log_clear"), systemImage: "trash.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .red.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
            }
        }
    }
    
    private var logStatsView: some View {
        let stats = LogManager.shared.getLogStats()
        
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("\(stats.count)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                Text(LocalizedStringProvider.localized("log_entries"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .frame(height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "opticaldiscdrive.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(String(format: "%.1f KB", stats.sizeKB))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                Text("Dateigröße")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
        .id(logRefreshTrigger)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                hapticNotification.notificationOccurred(.success)
                saveSettings()
                if isInitialSetup {
                    isSetupCompleted = true
                } else {
                    dismiss()
                }
            }) {
                HStack {
                    Image(systemName: isInitialSetup ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                        .font(.title3)
                    Text(isInitialSetup
                         ? LocalizedStringProvider.localized("save_and_start")
                         : LocalizedStringProvider.localized("save_changes"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: Color.accentColor.opacity(0.4), radius: 10, x: 0, y: 5)
            }
            .disabled(tempServerURL.isEmpty || tempToken.isEmpty || tempHouseholdId.isEmpty)
            .opacity((tempServerURL.isEmpty || tempToken.isEmpty || tempHouseholdId.isEmpty) ? 0.5 : 1.0)
            
            if !isInitialSetup {
                Button(role: .destructive) {
                    hapticImpact.impactOccurred()
                    showResetConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.title3)
                        Text(LocalizedStringProvider.localized("reset_app"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.red, .red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .red.opacity(0.4), radius: 10, x: 0, y: 5)
                }
            }
        }
    }

    // MARK: - Modern Language Picker
    
    private var languagePickerModern: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(LocalizedStringProvider.localized("language"), systemImage: "globe")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Menu {
                ForEach(["de", "en", "fr", "es", "nl"], id: \.self) { code in
                    Button {
                        withAnimation {
                            tempLanguage = code
                            LocalizedStringProvider.overrideLanguage = code
                        }
                        hapticImpact.impactOccurred()
                    } label: {
                        Label {
                            HStack {
                                Text(languageName(for: code))
                                if tempLanguage == code {
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        } icon: {
                            Text(flagEmoji(for: code))
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    // Flagge und Sprachname im Button
                    HStack(spacing: 8) {
                        Text(flagEmoji(for: tempLanguage))
                            .font(.title3)
                        
                        Text(languageName(for: tempLanguage))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Modern Logo Picker
    
    private var logoPickerModern: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(LocalizedStringProvider.localized("app_logo"), systemImage: "app.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                ForEach(["Classic", "Modern"], id: \.self) { name in
                    modernLogoCard(name: name)
                }
            }
        }
    }
    
    private func modernLogoCard(name: String) -> some View {
        let imageName = name == "Classic" ? "LogoClassicPreview" : "LogoModernPreview"
        let isSelected = settings.selectedLogo == name
        let attribution = name == "Classic" ? "by Walfrosch92" : "by JackWeekes"
        
        return Button(action: {
            settings.selectedLogo = name
            updateAppIcon(for: name)
            hapticNotification.notificationOccurred(.success)
        }) {
            VStack(spacing: 8) {
                ZStack {
                    // Glow Effect für ausgewähltes Icon
                    if isSelected {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)
                            .blur(radius: 10)
                    }
                    
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    isSelected ? 
                                        LinearGradient(
                                            colors: [.accentColor, .accentColor.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                    lineWidth: isSelected ? 3 : 1.5
                                )
                        )
                        .shadow(color: isSelected ? .accentColor.opacity(0.4) : .black.opacity(0.1), 
                                radius: isSelected ? 8 : 4, 
                                x: 0, 
                                y: isSelected ? 4 : 2)
                }
                
                VStack(spacing: 2) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(.primary)
                    
                    Text(attribution)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Bindings
    
    private func binding(forHeaderKey index: Int) -> Binding<String> {
        switch index {
        case 1: return $optionalHeaderKey1
        case 2: return $optionalHeaderKey2
        case 3: return $optionalHeaderKey3
        default: return .constant("")
        }
    }
    
    private func binding(forHeaderValue index: Int) -> Binding<String> {
        switch index {
        case 1: return $optionalHeaderValue1
        case 2: return $optionalHeaderValue2
        case 3: return $optionalHeaderValue3
        default: return .constant("")
        }
    }

    // MARK: - Helper Functions
    
    private func flagEmoji(for code: String) -> String {
        switch code {
        case "de": return "🇩🇪"
        case "en": return "🇬🇧"
        case "fr": return "🇫🇷"
        case "es": return "🇪🇸"
        case "nl": return "🇳🇱"
        default: return "🌍"
        }
    }

    private func logoCard(name: String) -> some View {
        let imageName = name == "Classic" ? "LogoClassicPreview" : "LogoModernPreview"
        let isSelected = settings.selectedLogo == name
        let attribution = name == "Classic" ? "by Walfrosch92" : "by JackWeekes"

        return Button(action: {
            settings.selectedLogo = name
            updateAppIcon(for: name)
        }) {
            VStack(spacing: 4) {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.4), lineWidth: isSelected ? 3 : 1)
                    )
                    .shadow(color: isSelected ? .accentColor.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)

                Text(name)
                    .font(.footnote)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(.primary)

                Text(attribution)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func InputField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func SecureFieldView(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            SecureField("", text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func languageName(for code: String) -> String {
        switch code {
        case "de": return "Deutsch"
        case "en": return "English"
        case "fr": return "Français"
        case "es": return "Español"
        case "nl": return "Dutch"
        default: return code
        }
    }

    private func updateAppIcon(for name: String) {
        guard UIApplication.shared.supportsAlternateIcons else {
            logMessage("❌ App-Icon-Wechsel nicht unterstützt")
            return
        }

        // Bestimme den Icon-Namen basierend auf Logo-Auswahl
        // Classic = Primary Icon (nil), Modern = AppIcon2
        // iOS wählt automatisch die richtige Light/Dark Variante aus der Info.plist
        let iconName: String? = (name == "Classic") ? nil : "AppIcon2"

        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                logMessage("❌ Fehler beim Wechseln des App-Icons: \(error.localizedDescription)")
            } else {
                logMessage("✅ App-Icon gewechselt zu \(iconName ?? "Standard-Icon")")
            }
        }
    }

    private func saveSettings() {
        settings.serverURL = tempServerURL
        settings.token = tempToken
        settings.householdId = tempHouseholdId
        settings.sendOptionalHeaders = tempSendOptionalHeaders
        settings.optionalHeaderKey1 = optionalHeaderKey1
        settings.optionalHeaderValue1 = optionalHeaderValue1
        settings.optionalHeaderKey2 = optionalHeaderKey2
        settings.optionalHeaderValue2 = optionalHeaderValue2
        settings.optionalHeaderKey3 = optionalHeaderKey3
        settings.optionalHeaderValue3 = optionalHeaderValue3
        settings.shoppingListId = tempShoppingListId
        settings.selectedLanguage = tempLanguage
        settings.apiVersion = tempApiVersion
        settings.showRecipeImages = tempShowRecipeImages
        settings.enableLogging = tempEnableLogging
        LocalizedStringProvider.overrideLanguage = nil
    }

    private func loadSettings() {
        tempServerURL = settings.serverURL
        tempToken = settings.token
        tempHouseholdId = settings.householdId
        tempShoppingListId = settings.shoppingListId
        tempSendOptionalHeaders = settings.sendOptionalHeaders
        optionalHeaderKey1 = settings.optionalHeaderKey1
        optionalHeaderValue1 = settings.optionalHeaderValue1
        optionalHeaderKey2 = settings.optionalHeaderKey2
        optionalHeaderValue2 = settings.optionalHeaderValue2
        optionalHeaderKey3 = settings.optionalHeaderKey3
        optionalHeaderValue3 = settings.optionalHeaderValue3
        tempLanguage = settings.selectedLanguage
        tempApiVersion = settings.apiVersion
        tempShowRecipeImages = settings.showRecipeImages
        tempEnableLogging = settings.enableLogging
        LocalizedStringProvider.overrideLanguage = tempLanguage
    }

    private func resetAppSettings() {
        settings.serverURL = ""
        settings.token = ""
        settings.householdId = "Family"
        settings.shoppingListId = ""
        settings.sendOptionalHeaders = false
        settings.optionalHeaderKey1 = ""
        settings.optionalHeaderValue1 = ""
        settings.optionalHeaderKey2 = ""
        settings.optionalHeaderValue2 = ""
        settings.optionalHeaderKey3 = ""
        settings.optionalHeaderValue3 = ""
        settings.selectedLanguage = "de"
        settings.selectedLogo = "Classic"
        settings.apiVersion = .v2_8
        settings.showRecipeImages = true
        settings.enableLogging = true
    }

    private func fetchShoppingLists() async {
        guard !tempServerURL.isEmpty, !tempToken.isEmpty else { return }

        isLoadingShoppingLists = true
        var headers: [String: String] = [:]
        if tempSendOptionalHeaders {
            headers[optionalHeaderKey1] = optionalHeaderValue1
            headers[optionalHeaderKey2] = optionalHeaderValue2
            headers[optionalHeaderKey3] = optionalHeaderValue3
        }

        if let url = URL(string: tempServerURL) {
            APIService.shared.configure(baseURL: url, token: tempToken, optionalHeaders: headers)

            do {
                shoppingLists = try await APIService.shared.fetchMinimalShoppingLists()
                if tempShoppingListId.isEmpty, let first = shoppingLists.first {
                    tempShoppingListId = first.id
                }
                hapticNotification.notificationOccurred(.success)
            } catch {
                logMessage("❌ Fehler beim Laden der Listen: \(error.localizedDescription)")
                hapticNotification.notificationOccurred(.error)
            }
        }

        isLoadingShoppingLists = false
    }
    
    // MARK: - Logging-Funktionen
    
    /// Zeigt Logs in einer Preview an
    private func showLogsPreview() {
        let logs = LogManager.shared.getLogs()
        logAlertMessage = logs.isEmpty ? "Keine Logs vorhanden" : logs
        showLogAlert = true
    }
    
    /// Löscht alle Logs mit verbessertem UI-Update
    private func clearLogs() {
        // Haptic Feedback VORHER
        hapticNotification.notificationOccurred(.warning)
        
        // Logs löschen
        LogManager.shared.clearLogs()
        
        // UI-Refresh triggern durch State-Änderung
        withAnimation {
            logRefreshTrigger = UUID()
        }
        
        // Success Haptic NACH erfolgreichem Löschen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            hapticNotification.notificationOccurred(.success)
        }
        
        // SwiftUI Alert statt UIKit (für bessere Integration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            logAlertMessage = "Alle Log-Einträge wurden gelöscht."
            showLogAlert = true
        }
    }
}

// MARK: - Custom UI Components

/// Moderne Karte für Sektionen
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(
        title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [iconColor, iconColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

/// Modernes Input Field mit Icon
struct ModernInputField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}

/// Modernes Secure Field mit Icon
struct ModernSecureField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}

/// Moderner Toggle mit Icon und optionalem Subtitle
struct ModernToggle: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}
