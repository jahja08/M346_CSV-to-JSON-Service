if [ $# -ne 3 ]; then
    echo "Usage: $0 <IN_BUCKET> <OUT_BUCKET> <LAMBDA_FUNCTION_NAME>"
    exit 1
fi

IN_BUCKET=$1
OUT_BUCKET=$2
LAMBDA_FUNCTION_NAME=$3

# CSV-Dateien in den Input-Bucket hochladen und verarbeiten
for CSV_Datei in ./input/*.csv; do
    if [ -f "$CSV_Datei" ]; then
        aws s3 cp "$CSV_Datei" s3://$IN_BUCKET
        if [ $? -eq 0 ]; then
            echo "CSV-Datei erfolgreich hochgeladen: $CSV_Datei"
            if [ -f "./input/uploads/$(basename "$CSV_Datei")" ]; then
                TIMESTAMP=$(date +%s)
                mv "$CSV_Datei" "./input/uploads/$(basename "$CSV_Datei" .csv)_$TIMESTAMP.csv"
            else
                mv "$CSV_Datei" ./input/uploads/
            fi
            if [ $? -eq 0 ]; then
                echo "CSV-Datei erfolgreich in den Ordner 'uploads' verschoben: $CSV_Datei"
            else
                echo "Fehler beim Verschieben der CSV-Datei in den Ordner 'uploads': $CSV_Datei"
                exit 1
            fi
        else
            echo "Fehler beim Hochladen der CSV-Datei: $CSV_Datei"
            exit 1
        fi

        # JSON-Datei aus dem S3-Bucket herunterladen
        JSON_FILE=$(basename "$CSV_Datei" .csv).json

        # Polling mechanism to check if the JSON file has been processed
        echo "Überprüfe, ob die Datei verarbeitet wurde: $JSON_FILE"
        while true; do
            if aws s3 ls s3://$OUT_BUCKET/$JSON_FILE > /dev/null 2>&1; then
                echo "Datei wurde verarbeitet: $JSON_FILE"
                break
            else
                echo "Datei noch nicht verarbeitet. Warte 5 Sekunden..."
                sleep 5
            fi
        done

        OUTPUT_FILE=./output/$JSON_FILE
        if [ -f "$OUTPUT_FILE" ]; then
            TIMESTAMP=$(date +%s)
            aws s3 cp s3://$OUT_BUCKET/$JSON_FILE ./output/$(basename "$CSV_Datei" .csv)_$TIMESTAMP.json
        else
            aws s3 cp s3://$OUT_BUCKET/$JSON_FILE ./output
        fi
    else
        echo "Keine CSV-Datei im Ordner 'input' gefunden. Beende den Prozess."
        break
    fi
done

# Aufräumen
while true; do
    read -p "Möchten Sie die erstellten S3 Buckets und die Lambda Funktion löschen? (y/n): " choice
    case "$choice" in 
        y|Y ) 
            aws s3 rb s3://$IN_BUCKET --force
            aws s3 rb s3://$OUT_BUCKET --force
            aws lambda delete-function --function-name $LAMBDA_FUNCTION_NAME
            echo "Ressourcen wurden gelöscht."
            break
            ;;
        n|N ) 
            echo "Ressourcen:"
            echo "IN_BUCKET: $IN_BUCKET"
            echo "OUT_BUCKET: $OUT_BUCKET"
            echo "LAMBDA_FUNCTION_NAME: $LAMBDA_FUNCTION_NAME"
            echo "Ressourcen wurden beibehalten."
            break
            ;;
        * ) 
            echo "Ungültige Eingabe. Bitte geben Sie 'y' oder 'n' ein."
            ;;
    esac
done