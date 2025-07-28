# **Salary Payment File Exporter**

This is a backend service for a payroll company. The system is designed to accept salary payment requests from internal systems, store them in a PostgreSQL database, and generate a daily export file to S3 and then push to bank's SFTP server

### **Core Features**

*    POST /payments: A REST endpoint to accept batches of payment requests.
*    A daily file export process that generates a .txt file for the bank.

### **Tech Stack**

    Ruby, SideKiq, Redis, Postgresql, AWS S3, SFTP

### Local Setup

run `docker compose up -d`

execute migration `bundle exec rake db:migrate`

start server `bundle exec puma -p 4567`

start sidekiq worker `bundle exec sidekiq -r ./app.rb`

to execute Unit test case `bundle exec rspec`

### **Entities**
```mermaid
    erDiagram
    configuration {
        uuid id PK
        varchar name
        varchar value
        boolean active
        timestamp created_at
        timestamp updated_at
    }

    company {
        uuid id PK
        varchar name
        boolean active
    }

    job {
        uuid id PK
        job_status status
        timestamp executed_at
        timestamp updated_at
        varchar output
    }

    payments {
        uuid id PK
        uuid employee_id
        uuid company_id FK
        uuid batch_id
        char(6) bsb
        char(9) account
        bigint amount_cents
        currency currency
        date pay_date
        payment_status status
        timestamp created_at
        timestamp updated_at
        uuid job_id FK
    }

    payments }|--|| company : "belongs to"
    payments }o--|| job : "can belong to"

```
### **API contracts**
POST /payments

Sample request
```json
POST /payments HTTP/1.1
Content-Type: application/json

{
    "company_id": "123",
    "batch_id": "931d1eb0-cd54-4b54-8fba-9893c93cebf1",
    "payments": [
{
    "employee_id": "1e0f4e4a-2bb3-48c6-8e15-6fe8d8ed0999",
    "bank_bsb": "062000",
    "bank_account": "12345678",
    "amount_cents": 250000,
    "currency": "AUD",
    "pay_date": "2025-10-09"
}
]
}
```
Sample response
```json
HTTP/1.1 201 Created
Location: /payments/batches/a1b2c3d4-e5f6-7890-1234-567890abcdef
{"message":"Accepted: A batch of 2 payments has been enqueued for processing."}
```

Sequence diagram
```mermaid
sequenceDiagram
    participant Client
    participant API Endpoint
    participant Job Queue
    participant Background Worker
    participant Database

    Client->>API Endpoint: POST /payments (with batch data)
    activate API Endpoint

    API Endpoint->>API Endpoint: 1. Synchronous Validation
    alt Validation Success
        API Endpoint->>Job Queue: 2. Enqueue Job
        API Endpoint-->>Client: 3. Respond 201 Created
    else Validation Failure
        API Endpoint-->>Client: 400 Bad Request
    end
    deactivate API Endpoint

    %% --- Asynchronous Processing ---
    Background Worker->>Job Queue: 4. Dequeue Job
    activate Background Worker

    Background Worker->>Database: 5. BEGIN TRANSACTION
    activate Database
    Background Worker->>Database: 6. Bulk INSERT payments
    Background Worker->>Database: 7. COMMIT TRANSACTION
    deactivate Database
    deactivate Background Worker
```
### Batch job

Sequence diagram
```mermaid
sequenceDiagram
    actor CronScheduler
    participant PaymentExporter
    participant Database
    participant S3
    participant SftpStreamer
    participant SFTPServer

    CronScheduler->>+PaymentExporter: Trigger perform()

    rect rgba(200, 220, 255, .5)
        note over PaymentExporter, Database: Start DB Transaction
        PaymentExporter->>+Database: Create Job record (status: pending)
        Database-->>-PaymentExporter: Return new Job record
        PaymentExporter->>+Database: Find pending Payments
        Database-->>-PaymentExporter: Return payment records
        Note over PaymentExporter: Generate local CSV file
        PaymentExporter->>+Database: Update Payments (status: exported, job_id)
        Database-->>-PaymentExporter: Confirm update
        PaymentExporter->>+S3: Upload CSV file
        S3-->>-PaymentExporter: Confirm upload
        PaymentExporter->>+SftpStreamer: queue file streamer Job
        PaymentExporter->>+Database: Update Job record (status: success)
        Database-->>-PaymentExporter: Confirm update
        note over PaymentExporter, Database: Commit DB Transaction (Rollbacks on failure)
    end
    deactivate PaymentExporter

    SftpStreamer->>+S3: Stream file
    S3-->>-SftpStreamer: File chunks
    SftpStreamer->>+SFTPServer: Upload file stream
    SFTPServer-->>-SftpStreamer: Confirm upload
    deactivate SftpStreamer
```
#### Batch job analysis:

Pros:
*   Atomic & Safe: Uses a database transaction to ensure data integrity. SFTP file transfer and database update are atomic and can be safely retried

Cons:
*    Long-Running Transaction: Possible database dead-lock due to long running transaction. Possible fix is to use a staging table
*    High Memory Use:Reading the entire file into memory for the S3 upload doesn't scale well for very large files. Possible improvement: directly stream file to S3
