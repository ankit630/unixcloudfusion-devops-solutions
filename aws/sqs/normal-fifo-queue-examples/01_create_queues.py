import boto3

sqs = boto3.client('sqs')

# Create a Standard queue
standard_queue = sqs.create_queue(
    QueueName='MyStandardQueue'
)
print(f"Standard Queue URL: {standard_queue['QueueUrl']}")

# Create a FIFO queue
fifo_queue = sqs.create_queue(
    QueueName='MyFifoQueue.fifo',
    Attributes={
        'FifoQueue': 'true',
        'ContentBasedDeduplication': 'true'
    }
)
print(f"FIFO Queue URL: {fifo_queue['QueueUrl']}")

# Save queue URLs to files for later use
with open('standard_queue_url.txt', 'w') as f:
    f.write(standard_queue['QueueUrl'])
with open('fifo_queue_url.txt', 'w') as f:
    f.write(fifo_queue['QueueUrl'])