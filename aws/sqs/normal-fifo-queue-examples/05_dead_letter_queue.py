import boto3
import time

sqs = boto3.client('sqs')

# Create a dead-letter queue
dlq = sqs.create_queue(
    QueueName='MyDeadLetterQueue'
)
dlq_url = dlq['QueueUrl']

# Get the ARN of the dead-letter queue
dlq_attributes = sqs.get_queue_attributes(
    QueueUrl=dlq_url,
    AttributeNames=['QueueArn']
)
dlq_arn = dlq_attributes['Attributes']['QueueArn']

# Create a main queue with the dead-letter queue
main_queue = sqs.create_queue(
    QueueName='MainQueueWithDLQ',
    Attributes={
        'RedrivePolicy': f'{{"deadLetterTargetArn":"{dlq_arn}","maxReceiveCount":"2"}}'
    }
)
main_queue_url = main_queue['QueueUrl']

# Send a message to the main queue
sqs.send_message(
    QueueUrl=main_queue_url,
    MessageBody='Test message for DLQ'
)

# Simulate processing failure
for attempt in range(3):
    response = sqs.receive_message(
        QueueUrl=main_queue_url,
        MaxNumberOfMessages=1,
        VisibilityTimeout=5
    )
    
    if 'Messages' in response:
        message = response['Messages'][0]
        print(f"Attempt {attempt + 1}: Received message from main queue: {message['Body']}")
        print("Simulating processing failure (not deleting the message)")
        time.sleep(6)  # Wait for visibility timeout to expire
    else:
        print(f"Attempt {attempt + 1}: No message received from main queue")

# Check the dead-letter queue
time.sleep(10)  # Wait for the message to be moved to DLQ
response = sqs.receive_message(
    QueueUrl=dlq_url,
    MaxNumberOfMessages=1
)

if 'Messages' in response:
    message = response['Messages'][0]
    print(f"Message received in dead-letter queue: {message['Body']}")
    
    # Clean up
    sqs.delete_message(
        QueueUrl=dlq_url,
        ReceiptHandle=message['ReceiptHandle']
    )
else:
    print("No message received in dead-letter queue")

# Delete queues
sqs.delete_queue(QueueUrl=main_queue_url)
sqs.delete_queue(QueueUrl=dlq_url)