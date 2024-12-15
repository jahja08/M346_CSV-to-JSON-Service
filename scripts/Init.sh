#!/bin/bash

if [ -z "$1" ]; then
    echo "Bitte geben Sie Ihre AWS Account ID als Parameter an."
    exit 1
fi

# Variablen
IN_BUCKET="csv-to-json-in-bucket-$(date +%s)-$RANDOM"
OUT_BUCKET="csv-to-json-out-bucket-$(date +%s)-$RANDOM"
LAMBDA_FUNCTION_NAME="Csv2JsonFunction"
ACCOUNT_ID=$1
EXISTING_ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/LabRole"
ZIP_FILE="lambda_function.zip"
LAMBDA_HANDLER="lambda_function.lambda_handler"
RUNTIME="python3.8"
REGION="us-east-1"
TIMEOUT=30  # Timeout auf 30 Sekunden setzen

# S3 Buckets erstellen
aws s3 mb s3://$IN_BUCKET --region $REGION
aws s3 mb s3://$OUT_BUCKET --region $REGION

# Lambda Funktion erstellen
cd src
zip $ZIP_FILE lambda_function.py
cd ..
if aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME > /dev/null 2>&1; then
    echo "Lambda Funktion existiert bereits."
    echo "Lösche Lambda Funktion..."
    aws lambda delete-function --function-name $LAMBDA_FUNCTION_NAME > /dev/null
fi

if aws lambda create-function \
    --function-name $LAMBDA_FUNCTION_NAME \
    --zip-file fileb://src/$ZIP_FILE \
    --handler $LAMBDA_HANDLER \
    --runtime $RUNTIME \
    --role $EXISTING_ROLE_ARN \
    --timeout $TIMEOUT \
    --environment Variables="{IN_BUCKET=$IN_BUCKET,OUT_BUCKET=$OUT_BUCKET}"> /dev/null 2>&1; then
    echo "Lambda Funktion erfolgreich erstellt."
else
    echo "Fehler beim Erstellen der Lambda Funktion."
    exit 1
fi

aws lambda add-permission \
  --function-name $LAMBDA_FUNCTION_NAME \
  --statement-id S3InvokePermission \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::$IN_BUCKET > /dev/null
  

# S3 Trigger hinzufügen
LAMBDA_ARN="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$LAMBDA_FUNCTION_NAME"
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|YOUR_ACCOUNT_ID|$ACCOUNT_ID|g" src/notification.json
    sed -i '' "s|YOUR_LAMBDA_ARN|$LAMBDA_ARN|g" src/notification.json
else
    sed -i "s|YOUR_ACCOUNT_ID|$ACCOUNT_ID|g" src/notification.json
    sed -i "s|YOUR_LAMBDA_ARN|$LAMBDA_ARN|g" src/notification.json
fi

aws s3api put-bucket-notification-configuration \
    --bucket $IN_BUCKET \
    --notification-configuration file://src/notification.json

echo "S3 Trigger erfolgreich hinzugefügt."


while true; do
    read -p "Möchtest du die RunPipeline.sh ausführen? (y/n): " choice
    case "$choice" in 
        y|Y ) 
            echo "Führe RunPipeline.sh aus..."
            ./scripts/RunPipeline.sh $IN_BUCKET $OUT_BUCKET $LAMBDA_FUNCTION_NAME
            exit 0
            ;;
        n|N ) 
            echo "Führe RunPipeline.sh manuell aus, um den Prozess zu starten."
            eche "IN_BUCKET: $IN_BUCKET"
            echo "OUT_BUCKET: $OUT_BUCKET"
            echo "LAMBDA_FUNCTION_NAME: $LAMBDA_FUNCTION_NAME"
            echo "Beende Initialisierung."
            exit 0
            ;;
        * ) 
            echo "Ungültige Eingabe."
            ;;
    esac
done