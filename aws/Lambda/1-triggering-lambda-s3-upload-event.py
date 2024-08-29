import json
import boto3    

def lambda_handler(event, context):
    try:
        bucket_name = event['Records'][0]['s3']['bucket']['name']
        object_key = event['Records'][0]['s3']['object']['key']
        print(f"Bucket: {bucket_name}, key: {object_key}")
        
        s3 = boto3.client('s3')
        
        download_path = f"/tmp/{object_key}"
        print(f"Downloading file from S3 bucket: {bucket_name} with key: {object_key}")
        s3.download_file(bucket_name, object_key, download_path)
        print(f'file downloaded to {download_path}')
            
        return {
            'statusCode': 200,
            'body': json.dumps(f"Bucket: {bucket_name}, key: {object_key}, Downloaded to: {download_path}")
        }
    except KeyError as e:
        print(f"Missing key: {e}")
        return {
            'statusCode': 404,
            'body': json.dumps(f"Missing key: {e}")
        }
    except Exception as e:
        print(f"An error occurred: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"An error occurred: {e}")
        }