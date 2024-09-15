import boto3
import threading
import time

sqs = boto3.client('sqs')

# Create a queue with long polling enabled
long_poll_queue = sqs.create_queue(
    QueueName='LongPollQueue',
    Attributes={
        'ReceiveMessageWaitTimeSeconds': '20'  # Wait up to 20 seconds for messages
    }
)
queue_url = long_poll_queue['QueueUrl']

def delayed_send():
    time.sleep(10)  # Wait for 10 seconds before sending the message
    sqs.send_message(
        QueueUrl=queue_url,
        MessageBody='Delayed message for long polling demo'
    )
    print("Message sent after 10 seconds delay")

# Start a thread to send a delayed message
threading.Thread(target=delayed_send).start()

print("Starting long polling (waiting up to 20 seconds for a message)...")
start_time = time.time()

# Use long polling when receiving messages
response = sqs.receive_message(
    QueueUrl=queue_url,
    MaxNumberOfMessages=1,
    WaitTimeSeconds=20
)

end_time = time.time()
elapsed_time = end_time - start_time

if 'Messages' in response:
    message = response['Messages'][0]
    print(f"Received message after {elapsed_time:.2f} seconds: {message['Body']}")
    
    # Delete the message
    sqs.delete_message(
        QueueUrl=queue_url,
        ReceiptHandle=message['ReceiptHandle']
    )
else:
    print(f"No messages received after {elapsed_time:.2f} seconds")

# Clean up
sqs.delete_queue(QueueUrl=queue_url)