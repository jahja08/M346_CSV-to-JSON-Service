import json
import csv
import boto3
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    in_bucket = os.environ['IN_BUCKET']
    out_bucket = os.environ['OUT_BUCKET']
    
    for record in event['Records']:
        key = record['s3']['object']['key']
        csv_file = s3.get_object(Bucket=in_bucket, Key=key)
        csv_content = csv_file['Body'].read().decode('utf-8').splitlines()
        
        reader = csv.DictReader(csv_content)
        json_content = json.dumps([row for row in reader])
        
        json_key = key.replace('.csv', '.json')
        s3.put_object(Bucket=out_bucket, Key=json_key, Body=json_content)
        
    return {
        'statusCode': 200,
        'body': json.dumps('CSV to JSON conversion successful')
    }