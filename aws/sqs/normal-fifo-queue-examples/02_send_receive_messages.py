import boto3

sqs = boto3.client('sqs')

# Read queue URLs
with open('standard_queue_url.txt', 'r') as f:
    standard_queue_url = f.read().strip()
with open('fifo_queue_url.txt', 'r') as f:
    fifo_queue_url = f.read().strip()

# Send messages
standard_response = sqs.send_message(
    QueueUrl=standard_queue_url,
    MessageBody='Hello from Standard Queue!'
)
print(f"Message sent to Standard Queue. MessageId: {standard_response['MessageId']}")

fifo_response = sqs.send_message(
    QueueUrl=fifo_queue_url,
    MessageBody='Hello from FIFO Queue!',
    MessageGroupId='MyMessageGroup',
    MessageDeduplicationId='UniqueDeduplicationId'
)
print(f"Message sent to FIFO Queue. MessageId: {fifo_response['MessageId']}")

# Receive and process messages
for queue_type, queue_url in [("Standard", standard_queue_url), ("FIFO", fifo_queue_url)]:
    response = sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=1
    )
    
    if 'Messages' in response:
        for message in response['Messages']:
            print(f"Received message from {queue_type} queue: {message['Body']}")
            
            # Delete the message
            sqs.delete_message(
                QueueUrl=queue_url,
                ReceiptHandle=message['ReceiptHandle']
            )
            print(f"Deleted message from {queue_type} queue")
    else:
        print(f"No messages received from {queue_type} queue")