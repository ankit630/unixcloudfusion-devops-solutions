import boto3

sqs = boto3.client('sqs')

# Read FIFO queue URL
with open('fifo_queue_url.txt', 'r') as f:
    fifo_queue_url = f.read().strip()

# Send messages with deduplication
for i in range(2):
    response = sqs.send_message(
        QueueUrl=fifo_queue_url,
        MessageBody=f'Deduplication test {i+1}',
        MessageGroupId='DeduplicationGroup',
        MessageDeduplicationId='UniqueDeduplicationId'
    )
    print(f"Attempt {i+1} - MessageId: {response.get('MessageId', 'Not sent due to deduplication')}")

# Send messages to different message groups
for i in range(2):
    for group in ['GroupA', 'GroupB']:
        sqs.send_message(
            QueueUrl=fifo_queue_url,
            MessageBody=f'Message {i+1} for {group}',
            MessageGroupId=group,
            MessageDeduplicationId=f'{group}-{i}'
        )

# Receive and process messages
received_messages = []
while True:
    response = sqs.receive_message(
        QueueUrl=fifo_queue_url,
        MaxNumberOfMessages=10
    )
    
    if 'Messages' not in response:
        break
    
    for message in response['Messages']:
        print(f"Received: {message['Body']}")
        received_messages.append(message['Body'])
        
        # Delete the message
        sqs.delete_message(
            QueueUrl=fifo_queue_url,
            ReceiptHandle=message['ReceiptHandle']
        )

# Verify deduplication and ordering
expected_messages = [
    'Deduplication test 1',
    'Message 1 for GroupA',
    'Message 2 for GroupA',
    'Message 1 for GroupB',
    'Message 2 for GroupB'
]

if received_messages == expected_messages:
    print("Deduplication and ordering worked as expected")
else:
    print("Unexpected message order or content")
    print(f"Expected: {expected_messages}")
    print(f"Received: {received_messages}")