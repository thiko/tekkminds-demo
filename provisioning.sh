#!/bin/bash

# Skript zur Bereitstellung der AWS-Infrastruktur für die TekkMinds Image Gallery
# Verwendung: ./provisioning.sh <aws-profile-name>

set -e

# Überprüfe, ob ein AWS-Profil angegeben wurde
if [ -z "$1" ]; then
  echo "Fehler: Kein AWS-Profil angegeben."
  echo "Verwendung: ./provisioning.sh <aws-profile-name>"
  exit 1
fi

AWS_PROFILE=$1
TARGET_ACCOUNT="911167893130"

echo "Verwende AWS-Profil: $AWS_PROFILE"
echo "Ziel-AWS-Konto: $TARGET_ACCOUNT"

# Überprüfe, ob das AWS-Profil existiert
if ! aws configure list-profiles | grep -q "^$AWS_PROFILE$"; then
  echo "Fehler: AWS-Profil '$AWS_PROFILE' existiert nicht."
  exit 1
fi

# Überprüfe, ob das Profil auf das richtige Konto zugreift
ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query "Account" --output text)
if [ "$ACCOUNT_ID" != "$TARGET_ACCOUNT" ]; then
  echo "Fehler: Das AWS-Profil '$AWS_PROFILE' hat keinen Zugriff auf das Zielkonto '$TARGET_ACCOUNT'."
  echo "Aktuelles Konto: $ACCOUNT_ID"
  exit 1
fi

echo "AWS-Konto verifiziert: $ACCOUNT_ID"

# Wechsle in das CDK-Verzeichnis
cd cdk

# Installiere Abhängigkeiten
echo "Installiere Abhängigkeiten..."
npm install

# Bootstrapping (falls noch nicht geschehen)
echo "Führe CDK-Bootstrapping für eu-central-1 durch..."
npx cdk bootstrap --profile $AWS_PROFILE

echo "Führe CDK-Bootstrapping für us-east-1 durch (für Lambda@Edge)..."
npx cdk bootstrap aws://$ACCOUNT_ID/us-east-1 --profile $AWS_PROFILE

# Synthetisiere CloudFormation-Template
echo "Synthetisiere CloudFormation-Template..."
npx cdk synth --profile $AWS_PROFILE

# Bereitstellen des Stacks
echo "Stelle Stacks bereit..."
npx cdk deploy --all --profile $AWS_PROFILE --require-approval never

echo "Bereitstellung abgeschlossen!"

# Zeige die Stack-Outputs an
echo "Stack-Outputs:"
aws cloudformation describe-stacks --stack-name TekkMindsImageGalleryStack --profile $AWS_PROFILE --query "Stacks[0].Outputs" --output table

echo "Infrastruktur erfolgreich bereitgestellt!" 