import SwiftUI
import PhotosUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

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

struct RecipeUploadView: View {
    private enum UploadState: Equatable {
        case idle
        case uploading
        case success
        case failure(String)
    }

    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var recipeURL: String = ""
    @State private var uploadState: UploadState = .idle
    @State private var hasAppeared = false
    @State private var showingPDFPicker = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    // Task-Tracking zur Vermeidung von Race Conditions
    @State private var currentUploadTask: Task<Void, Never>?

    // Maximale Dateigröße in Bytes (z.B. 10MB)
    private let maxFileSize: Int64 = 10 * 1024 * 1024 // 10 MB
    
    // Maximale Bildgröße nach Konvertierung
    private let maxImageSizeInBytes = 5 * 1024 * 1024 // 5 MB für JPEG
    
    // Computed property für Upload-Status
    private var isUploading: Bool {
        if case .uploading = uploadState {
            return true
        }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(LocalizedStringProvider.localized("upload_recipe"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.top)

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(LocalizedStringProvider.localized("upload_url_section_title"))
                                .font(.title2)
                                .bold()
                                .foregroundColor(.primary)

                            Text(LocalizedStringProvider.localized("enter_recipe_url_hint"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField(
                                LocalizedStringProvider.localized("image_placeholder_url"),
                                text: $recipeURL
                            )
                            .textFieldStyle(.roundedBorder)

                            Button {
                                uploadFromURL()
                            } label: {
                                Label(
                                    LocalizedStringProvider.localized("upload_from_url"),
                                    systemImage: "link"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(recipeURL.isEmpty || isUploading)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }

                    Divider()

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(LocalizedStringProvider.localized("upload_image_section_title"))
                                .font(.title2)
                                .bold()
                                .foregroundColor(.primary)

                            Text(LocalizedStringProvider.localized("image_upload_hint"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack {
                                Spacer()
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    Label(LocalizedStringProvider.localized("select_image"), systemImage: "photo")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isUploading)

                                Button {
                                    showingPDFPicker = true
                                } label: {
                                    Label(LocalizedStringProvider.localized("select_pdf"), systemImage: "doc.richtext")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isUploading)
                                Spacer()
                            }

                            if uploadState == .uploading {
                                HStack {
                                    Spacer()
                                    ProgressView(LocalizedStringProvider.localized("uploading_image"))
                                        .padding(.top, 12)
                                    Spacer()
                                }
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.accentColor)
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedStringProvider.localized("openai_hint_title"))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text(LocalizedStringProvider.localized("openai_hint_message"))
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            uploadState = .idle
        }
        .onDisappear {
            // Abbrechen laufender Uploads beim Verlassen
            currentUploadTask?.cancel()
        }
        .onChange(of: selectedItem) {
            guard let newItem = selectedItem else { return }
            
            // Vorherige Tasks abbrechen
            currentUploadTask?.cancel()
            
            currentUploadTask = Task {
                await handleImageSelection(newItem)
            }
        }
        .fileImporter(
            isPresented: $showingPDFPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            // Vorherige Tasks abbrechen
            currentUploadTask?.cancel()
            
            currentUploadTask = Task {
                await handlePDFImport(result: result)
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text(LocalizedStringProvider.localized("upload_error")),
                message: Text(errorMessage ?? "Unknown error"),
                dismissButton: .default(Text(LocalizedStringProvider.localized("ok")))
            )
        }
        .alert(isPresented: $showSuccessAlert) {
            Alert(
                title: Text(LocalizedStringProvider.localized("upload_success")),
                dismissButton: .default(Text(LocalizedStringProvider.localized("ok"))) {
                    resetForm()
                }
            )
        }
    }

    private func handlePDFImport(result: Result<[URL], Error>) async {
        guard case .success(let urls) = result,
              let url = urls.first else {
            await showResult(success: false, errorMessage: LocalizedStringProvider.localized("upload_failed"))
            return
        }
        
        // WICHTIG: Sofort sicheren Zugriff anfordern
        guard url.startAccessingSecurityScopedResource() else {
            logMessage("❌ Kein Zugriff auf die Datei gewährt")
            errorMessage = "Keine Berechtigung zum Zugriff auf die Datei"
            showErrorAlert = true
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            // Jetzt können wir die Dateigröße prüfen
            let fileSize = try getFileSize(for: url)
            if fileSize > maxFileSize {
                errorMessage = LocalizedStringProvider.localized("pdf_too_large")
                showErrorAlert = true
                return
            }
            
            // PDF in Bild konvertieren (ohne erneuten Security-Scoped-Zugriff!)
            guard let image = await renderPDFToImage(from: url, maxWidth: 1200, maxHeight: 4000) else {
                errorMessage = "PDF konnte nicht in Bild konvertiert werden"
                showErrorAlert = true
                return
            }
            
            // Bildgröße optimieren
            guard let optimizedImage = optimizeImageSize(image) else {
                errorMessage = "Bild konnte nicht optimiert werden"
                showErrorAlert = true
                return
            }

            await MainActor.run {
                uploadState = .uploading
            }
            
            do {
                _ = try await uploadImageWithHeaders(optimizedImage)
                await showResult(success: true)
            } catch {
                logMessage("❌ Upload fehlgeschlagen: \(error)")
                await showResult(success: false, errorMessage: error.localizedDescription)
            }
            
        } catch {
            logMessage("❌ Fehler bei PDF-Verarbeitung: \(error)")
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func getFileSize(for url: URL) throws -> Int64 {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resourceValues.fileSize ?? 0)
    }

    private func optimizeImageSize(_ image: UIImage) -> UIImage? {
        var compressionQuality: CGFloat = 0.8
        var imageData: Data?
        
        // Versuche verschiedene Komprimierungsstufen
        for _ in 0..<6 {
            imageData = image.jpegData(compressionQuality: compressionQuality)
            
            if let data = imageData, data.count <= maxImageSizeInBytes {
                return UIImage(data: data)
            }
            
            compressionQuality -= 0.15
            
            // Sicherheitsprüfung: Verhindere negative Werte
            if compressionQuality < 0.1 {
                break
            }
        }
        
        // Wenn immer noch zu groß, skaliere das Bild herunter
        guard let currentData = imageData, currentData.count > 0 else {
            return nil
        }
        
        let originalSize = image.size
        let scaleFactor = min(1.0, sqrt(CGFloat(maxImageSizeInBytes) / CGFloat(currentData.count)))
        let newSize = CGSize(
            width: floor(originalSize.width * scaleFactor),
            height: floor(originalSize.height * scaleFactor)
        )
        
        // Mindestgröße sicherstellen
        guard newSize.width > 100 && newSize.height > 100 else {
            logMessage("⚠️ Bild würde zu klein werden")
            return nil
        }
        
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1.0
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        // Versuche erneut zu komprimieren
        return resizedImage.jpegData(compressionQuality: 0.7).flatMap { UIImage(data: $0) }
    }

    private func handleImageSelection(_ item: PhotosPickerItem) async {
        guard !isUploading else { 
            logMessage("⚠️ Upload läuft bereits, Auswahl ignoriert")
            return 
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                await showResult(success: false, errorMessage: "Bild konnte nicht geladen werden")
                return
            }

            await MainActor.run {
                uploadState = .uploading
            }

            // ✅ Option 1: Nutze uploadImageWithHeaders (mit Debug-Logging)
            _ = try await uploadImageWithHeaders(image)
            
            // 💡 Option 2: Nutze APIService (falls obige nicht funktioniert)
            // _ = try await APIService.shared.uploadRecipeImage(image, translateLanguage: "de-DE")
            
            await showResult(success: true)
            
        } catch is CancellationError {
            logMessage("ℹ️ Bild-Upload wurde abgebrochen")
            await MainActor.run {
                uploadState = .idle
            }
        } catch {
            logMessage("❌ Upload-Fehler: \(error.localizedDescription)")
            await showResult(success: false, errorMessage: error.localizedDescription)
        }
    }

    private func uploadFromURL() {
        guard !recipeURL.isEmpty, !isUploading else { return }
        
        // URL-Validierung
        guard let url = URL(string: recipeURL),
              url.scheme == "http" || url.scheme == "https" else {
            errorMessage = "Ungültige URL. Bitte gib eine gültige HTTP(S)-URL ein."
            showErrorAlert = true
            return
        }

        uploadState = .uploading
        
        currentUploadTask?.cancel()
        currentUploadTask = Task {
            do {
                _ = try await APIService.shared.uploadRecipeFromURL(url: recipeURL)
                await showResult(success: true)
            } catch is CancellationError {
                logMessage("ℹ️ URL-Upload wurde abgebrochen")
                await MainActor.run {
                    uploadState = .idle
                }
            } catch {
                logMessage("❌ Upload-Fehler: \(error.localizedDescription)")
                await showResult(success: false, errorMessage: error.localizedDescription)
            }
        }
    }

    private func showResult(success: Bool, errorMessage: String? = nil) async {
        await MainActor.run {
            if success {
                showSuccessAlert = true
            } else {
                self.errorMessage = errorMessage ?? ""
                showErrorAlert = true
            }
            
            // Upload-Status zurücksetzen
            withAnimation {
                uploadState = .idle
            }
        }
    }

    private func resetForm() {
        recipeURL = ""
        selectedImage = nil
        selectedItem = nil
    }

    private func uploadImageWithHeaders(_ image: UIImage) async throws -> String {
        guard let baseURL = APIService.shared.getBaseURL(),
              let token = APIService.shared.getToken() else {
            throw URLError(.badURL)
        }

        let optionalHeaders = APIService.shared.getOptionalHeaders
        
        // ✅ KORREKTER Endpoint: /api/recipes/create/image
        // Dieser Endpoint unterstützt OpenAI!
        // Wichtig: Feld heißt "images" (Plural), nicht "image"
        // TODO: Sprache dynamisch machen statt "de-DE" hardzucoden
        var components = URLComponents(url: baseURL.appendingPathComponent("api/recipes/create/image"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "translateLanguage", value: "de-DE")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120 // OpenAI-Analyse kann länger dauern

        let boundary = UUID().uuidString
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        for (key, value) in optionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "UploadError", code: 0, userInfo: [
                NSLocalizedDescriptionKey: LocalizedStringProvider.localized("image_conversion_error")
            ])
        }
        
        logMessage("ℹ️ Upload-Bildgröße: \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file))")

        var body = Data()
        body.append("--\(boundary)\r\n")
        // ⚠️ WICHTIG: Feld heißt "images" (Plural), wie in der API-Doku!
        body.append("Content-Disposition: form-data; name=\"images\"; filename=\"image.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")

        request.httpBody = body
        
        // 🔍 Debug-Logging
        logMessage("🌐 Upload URL: \(request.url?.absoluteString ?? "nil")")
        logMessage("📦 Request Body Size: \(body.count) bytes")
        logMessage("🔑 Authorization Header: \(request.value(forHTTPHeaderField: "Authorization") != nil ? "✅ Set" : "❌ Missing")")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logMessage("❌ Keine HTTP Response erhalten")
            throw URLError(.badServerResponse)
        }
        
        logMessage("📡 HTTP Status Code: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? LocalizedStringProvider.localized("upload_failed")
            logMessage("❌ Upload-Fehler: \(errorMessage)")
            
            // 🔍 Spezifische Fehler-Hinweise
            if httpResponse.statusCode == 500 {
                logMessage("⚠️ Server-Fehler (500). Mögliche Ursachen:")
                logMessage("   - OpenAI API Key fehlt in Mealie")
                logMessage("   - OpenAI API Quota überschritten")
                logMessage("   - Mealie Server-Konfiguration fehlerhaft")
            } else if httpResponse.statusCode == 422 {
                logMessage("⚠️ Unprocessable Entity (422) - Ungültige Daten")
            }
            
            throw NSError(domain: "UploadError", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: errorMessage
            ])
        }

        logMessage("✅ Upload erfolgreich! OpenAI sollte das Bild nun analysieren.")
        logMessage("🎉 ALLES GEKLAPPT! Rezept wurde erstellt.")
        logMessage("📝 Response: \(String(data: data, encoding: .utf8)?.prefix(200) ?? "keine Daten")")
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\""))) ?? ""
    }
}

// MARK: - Helpers

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - PDF Rendering

/// Rendert ein PDF in ein UIImage mit korrekter Security-Scoped Resource-Verwaltung
/// - Parameters:
///   - url: Die URL des PDFs (muss bereits Security-Scoped Access haben!)
///   - maxWidth: Maximale Breite des resultierenden Bildes
///   - maxHeight: Maximale Höhe des resultierenden Bildes
/// - Returns: Das gerenderte Bild oder nil bei Fehler
private func renderPDFToImage(from url: URL, maxWidth: CGFloat, maxHeight: CGFloat) async -> UIImage? {
    // WICHTIG: Diese Funktion erwartet, dass der Security-Scoped Access bereits gewährt wurde!
    
    do {
        // Erstelle eine temporäre Kopie der PDF im Cache
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        
        try FileManager.default.copyItem(at: url, to: tempURL)
        
        defer {
            // Temporäre Datei aufräumen
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // Jetzt mit der temporären Datei arbeiten
        guard let document = CGPDFDocument(tempURL as CFURL),
              let page = document.page(at: 1) else {
            logMessage("❌ PDF konnte nicht geladen werden")
            return nil
        }

        let box = page.getBoxRect(.mediaBox)

        // Berechnung des Skalierungsfaktors
        let widthScale = maxWidth / box.width
        let heightScale = maxHeight / box.height
        let scale = min(widthScale, heightScale, 1.0)

        let targetSize = CGSize(
            width: floor(box.width * scale),
            height: floor(box.height * scale)
        )

        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.opaque = true
        rendererFormat.scale = 1.0 // Fixiere auf 1.0 für konsistente Größe

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))

            ctx.cgContext.translateBy(x: 0, y: targetSize.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            ctx.cgContext.scaleBy(x: scale, y: scale)

            ctx.cgContext.drawPDFPage(page)
        }
        
        logMessage("✅ PDF erfolgreich gerendert: \(targetSize)")
        return image
        
    } catch {
        logMessage("❌ Fehler beim Rendern des PDFs: \(error)")
        return nil
    }
}
// MARK: - Deprecated (kept for compatibility)

@available(*, deprecated, message: "Use renderPDFToImage instead")
func renderScaledPDFImage(from url: URL, maxWidth: CGFloat, maxHeight: CGFloat) -> UIImage? {
    // Diese alte Funktion hatte den Bug mit doppeltem Security-Scoped Access
    return nil
}

