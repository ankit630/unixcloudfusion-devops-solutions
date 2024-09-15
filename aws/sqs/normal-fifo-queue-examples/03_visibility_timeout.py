import boto3
import time

sqs = boto3.client('sqs')

# Create a new queue with custom visibility timeout
queue_with_timeout = sqs.create_queue(
    QueueName='QueueWithCustomTimeout',
    Attributes={
        'VisibilityTimeout': '10'  # 10 seconds
    }
)
queue_url = queue_with_timeout['QueueUrl']

# Send a message
sqs.send_message(
    QueueUrl=queue_url,
    MessageBody='Test visibility timeout'
)

# Receive the message
response = sqs.receive_message(
    QueueUrl=queue_url,
    MaxNumberOfMessages=1
)

if 'Messages' in response:
    message = response['Messages'][0]
    receipt_handle = message['ReceiptHandle']
    print(f"Received message: {message['Body']}")
    
    # Wait for 5 seconds
    print("Waiting for 5 seconds...")
    time.sleep(5)
    
    # Try to receive the message again (should not receive)
    response = sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=1
    )
    if 'Messages' in response:
        print("Message received again (unexpected)")
    else:
        print("Message not received (as expected due to visibility timeout)")
    
    # Wait for another 6 seconds (total 11 seconds)
    print("Waiting for another 6 seconds...")
    time.sleep(6)
    
    # Try to receive the message again (should receive)
    response = sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=1
    )
    if 'Messages' in response:
        print("Message received again (as expected after visibility timeout)")
    else:
        print("Message not received (unexpected)")

    # Clean up
    sqs.delete_message(
        QueueUrl=queue_url,
        ReceiptHandle=receipt_handle
    )
    sqs.delete_queue(QueueUrl=queue_url)
else:
    print("No message received")