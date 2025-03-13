# Thieme Image Gallery

Eine webbasierte Galerie zur Anzeige der Ergebnisse der internen Bildverarbeitungsanwendung.

## Projektübersicht

Diese Anwendung ermöglicht es Stakeholdern innerhalb des Unternehmens, die neuesten Ergebnisse der Bildverarbeitungsanwendung anzusehen, ohne dass einzelne Vorschauen gesendet werden müssen. Die Galerie zeigt für jedes verarbeitete Bild drei Varianten an:

- Original-Bild (aus dem Verzeichnis `resources/`)
- Bild mit entferntem Text (aus dem Verzeichnis `erased/`)
- Finales Ergebnis mit übersetztem Text (aus dem Verzeichnis `output/`)

## Infrastruktur

Die Anwendung verwendet folgende AWS-Dienste:

- **S3-Bucket**: Speichert die Bilder und die HTML-Galerie
- **CloudFront**: Stellt die Inhalte bereit und implementiert die Authentifizierung
- **Lambda@Edge**: Implementiert die Basisauthentifizierung für den Zugriff auf die Galerie

## Voraussetzungen

- AWS CLI installiert und konfiguriert
- Node.js und npm installiert
- AWS CDK installiert (`npm install -g aws-cdk`)

## Installation und Bereitstellung

### 1. Infrastruktur bereitstellen

Verwende das `provisioning.sh`-Skript, um die AWS-Infrastruktur bereitzustellen:

```bash
./provisioning.sh <aws-profile-name>
```

Dieses Skript:
- Überprüft, ob das angegebene AWS-Profil existiert und Zugriff auf das Zielkonto hat
- Installiert die CDK-Abhängigkeiten
- Führt das CDK-Bootstrapping durch (falls erforderlich)
- Stellt den CloudFormation-Stack bereit
- Zeigt die Stack-Outputs an

### 2. Bilder und HTML-Galerie bereitstellen

Verwende das `deploy.sh`-Skript, um die Bilder und die HTML-Galerie bereitzustellen:

```bash
./deploy.sh <aws-profile-name> [--max-images=100]
```

Optionale Parameter:
- `--generate-only`: Generiert nur die HTML-Galerie ohne Upload
- `--upload-only`: Lädt nur die Bilder und HTML-Galerie hoch ohne Generierung
- `--invalidate-only`: Invalidiert nur den CloudFront-Cache
- `--max-images=N`: Begrenzt die Anzahl der hochzuladenden Bilder (Standard: 100)

## Verzeichnisstruktur

- `cdk/`: CDK-Projektverzeichnis
  - `lib/`: CDK-Stack-Definition
  - `lambda/`: Lambda@Edge-Funktionen
- `resources/`: Verzeichnis für Original-Bilder
- `erased/`: Verzeichnis für Bilder mit entferntem Text
- `output/`: Verzeichnis für finale Bilder mit übersetztem Text
- `provisioning.sh`: Skript zur Bereitstellung der Infrastruktur
- `deploy.sh`: Skript zur Bereitstellung der Bilder und HTML-Galerie

## Authentifizierung

Die Galerie ist durch eine Basisauthentifizierung geschützt. Die Standardanmeldedaten sind:

- Benutzername: `thieme`
- Passwort: `gallery`

Diese Anmeldedaten können in der Lambda@Edge-Funktion (`cdk/lambda/auth.ts`) geändert werden.

## Lokale Vorschau

Um die Galerie lokal anzusehen, ohne sie auf AWS hochzuladen:

```bash
./deploy.sh <aws-profile-name> --generate-only
```

Öffne dann die Datei `temp_gallery/index.html` in deinem Browser. 