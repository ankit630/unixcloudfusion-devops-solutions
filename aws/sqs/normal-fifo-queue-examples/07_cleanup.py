import boto3

sqs = boto3.client('sqs')

# List all queues
response = sqs.list_queues()

if 'QueueUrls' in response:
    for queue_url in response['QueueUrls']:
        if any(name in queue_url for name in ['MyStandardQueue', 'MyFifoQueue', 'QueueWithCustomTimeout', 'MyDeadLetterQueue', 'MainQueueWithDLQ', 'LongPollQueue']):
            sqs.delete_queue(QueueUrl=queue_url)
            print(f"Deleted queue: {queue_url}")
else:
    print("No queues found")

# Remove queue URL files
import os
for filename in ['standard_queue_url.txt', 'fifo_queue_url.txt']:
    if os.path.exists(filename):
        os.remove(filename)
        print(f"Removed file: {filename}")