# Save Cost on Google Cloud SQL

This repository provides a script and guidance to help you minimize costs associated with Google Cloud SQL, especially for small or infrequently used databases.

## Problem

Cloud SQL instances incur a minimum cost (e.g., ~$1/month for storage) even when not actively used. For development, testing, or rarely accessed data, this can add up over time.

## Solution

Export your Cloud SQL data to a Google Cloud Storage bucket and delete the Cloud SQL instance when not needed. This approach reduces ongoing costs to only storage fees for the exported data, which are typically much lower.

## Usage

1. **Export Data**:  
    Use the provided script to export your Cloud SQL database to a Cloud Storage bucket.
2. **Delete Instance**:  
    Remove the Cloud SQL instance to stop incurring compute and storage charges.
3. **Restore When Needed**:  
    When you need the database again, create a new Cloud SQL instance and import the data from your Cloud Storage bucket.

## Example Script

```sh
# Export Cloud SQL database to Cloud Storage
gcloud sql export sql [INSTANCE_NAME] gs://[BUCKET_NAME]/[EXPORT_FILE].sql.gz \
  --database=[DATABASE_NAME]

# Delete the Cloud SQL instance
gcloud sql instances delete [INSTANCE_NAME]
```

## Reference: How to Save Money on Google Cloud SQL

- **Right-size your instances**: Choose appropriate CPU, memory, and storage.
- **Stop or pause idle instances**: Only pay for storage when stopped.
- **Leverage Committed Use Discounts**: Commit to usage for discounts.
- **Optimize storage and backups**: Retain only necessary backups and delete unused instances.
- **Optimize queries and application code**: Reduce resource consumption.
- **Monitor and set budget alerts**: Track usage and prevent overruns.

For more details, see the [Google Cloud SQL documentation](https://cloud.google.com/sql/docs).
