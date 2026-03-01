#!/bin/bash

# Script zum Erstellen einer stillen Audio-Datei für Background-Timer
# 
# Verwendung:
#   ./create_silent_audio.sh
#
# Benötigt: ffmpeg (installieren mit: brew install ffmpeg)

echo "🔇 Erstelle stille Audio-Datei für Timer..."

# Überprüfe ob ffmpeg installiert ist
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ ffmpeg ist nicht installiert!"
    echo "💡 Installieren Sie ffmpeg mit: brew install ffmpeg"
    echo ""
    echo "Alternative: Verwenden Sie Audacity:"
    echo "1. Öffnen Sie Audacity (https://www.audacityteam.org/)"
    echo "2. Erstellen Sie ein neues Projekt"
    echo "3. Wählen Sie 'Generate → Silence' (1 Sekunde)"
    echo "4. Exportieren Sie als WAV: 'File → Export → Export Audio'"
    echo "5. Format: WAV (Microsoft) signed 16-bit PCM"
    echo "6. Benennen Sie die Datei 'silent.wav'"
    echo "7. Fügen Sie die Datei zu Ihrem Xcode-Projekt hinzu"
    exit 1
fi

# Erstelle 1 Sekunde stille Audio mit ffmpeg
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -acodec pcm_s16le -ar 44100 -y silent.wav

if [ $? -eq 0 ]; then
    echo "✅ silent.wav erfolgreich erstellt!"
    echo ""
    echo "📝 Nächste Schritte:"
    echo "1. Öffnen Sie Ihr Xcode-Projekt"
    echo "2. Ziehen Sie 'silent.wav' in Ihr Projekt (in den Ordner mit 'alarm.wav')"
    echo "3. Stellen Sie sicher, dass 'Add to targets' für Ihr App-Target aktiviert ist"
    echo "4. Fertig! 🎉"
else
    echo "❌ Fehler beim Erstellen der Audio-Datei"
    exit 1
fi
