#!/bin/bash
# Cloud SQL Export & Delete Script (Fully Robust & Safe with gcloud IAM + IAM propagation)

set -e

PROJECT="uplifted-woods-459110-i5"
INSTANCE="n8n-db"
BUCKET_NAME="my-sql-backups-bucket"
REGION="asia-southeast1"
DB_NAME="postgres"      # adjust if different
EXPORT_FILE="n8n-db-$(date +%Y%m%d).sql.gz"
BUCKET="gs://$BUCKET_NAME"

# --- 1️⃣ Check/create bucket safely ---
echo "🔍 Checking if bucket $BUCKET exists..."
if gsutil ls -b "$BUCKET" >/dev/null 2>&1; then
    echo "✅ Bucket already exists."
else
    echo "📦 Bucket does not exist. Creating $BUCKET..."
    # Attempt to create, handle 409 (already exists) gracefully
    if ! gcloud storage buckets create "$BUCKET" \
        --project="$PROJECT" \
        --location="$REGION" \
        --default-storage-class=COLDLINE 2>/tmp/bucket_create.log; then
        if grep -q "already exists" /tmp/bucket_create.log; then
            echo "⚠ Bucket creation reported already exists. Continuing..."
        else
            echo "❌ Bucket creation failed:"
            cat /tmp/bucket_create.log
            exit 1
        fi
    else
        echo "✅ Bucket created."
    fi
fi

# --- 2️⃣ Grant Cloud SQL service account write access using gcloud ---
echo "🔑 Granting Cloud SQL service account write access to bucket..."
PROJECT_NUMBER=$(gcloud projects describe $PROJECT --format="value(projectNumber)")
EXPORT_SA="service-${PROJECT_NUMBER}@gcp-sa-cloud-sql.iam.gserviceaccount.com"

gcloud storage buckets add-iam-policy-binding $BUCKET \
  --member="serviceAccount:$EXPORT_SA" \
  --role="roles/storage.objectAdmin" \
  --project=$PROJECT \
  --quiet

echo "✅ Permissions granted to Cloud SQL export service account: $EXPORT_SA"
echo "⏳ Waiting 10 seconds for IAM propagation..."
sleep 10

# --- 3️⃣ Wait for ongoing operations ---
echo "⏳ Checking for ongoing operations on $INSTANCE..."
while [[ "$(gcloud sql operations list --instance=$INSTANCE --project=$PROJECT --sort-by="~startTime" --limit=1 --format='value(status)')" == "PENDING" || \
        "$(gcloud sql operations list --instance=$INSTANCE --project=$PROJECT --sort-by="~startTime" --limit=1 --format='value(status)')" == "RUNNING" ]]; do
    echo "   Operation in progress. Waiting 10 seconds..."
    sleep 10
done
echo "✅ No ongoing operations. Safe to proceed."

# --- 4️⃣ Patch instance to ALWAYS ---
echo "⚡ Ensuring Cloud SQL instance $INSTANCE is RUNNABLE..."
gcloud sql instances patch $INSTANCE \
  --activation-policy=ALWAYS \
  --project=$PROJECT

# --- 5️⃣ Wait until RUNNABLE ---
echo "⏳ Waiting for instance to become RUNNABLE..."
while [[ "$(gcloud sql instances describe $INSTANCE --project=$PROJECT --format='value(state)')" != "RUNNABLE" ]]; do
    sleep 5
    echo "   waiting..."
done
echo "✅ Instance is now RUNNABLE."

# --- 6️⃣ Export database ---
echo "📤 Exporting database $DB_NAME to $BUCKET/$EXPORT_FILE..."
EXPORT_OP=$(gcloud sql export sql $INSTANCE $BUCKET/$EXPORT_FILE \
  --database=$DB_NAME \
  --project=$PROJECT \
  --async \
  --format="value(name)")

# --- 7️⃣ Wait for export completion ---
echo "⏳ Waiting for export operation to complete..."
STATUS="PENDING"
while [[ "$STATUS" != "DONE" ]]; do
    STATUS=$(gcloud sql operations describe $EXPORT_OP --project=$PROJECT --format="value(status)")
    echo "   Export status: $STATUS"
    sleep 10
done
echo "✅ Export completed: $BUCKET/$EXPORT_FILE"

# --- 8️⃣ Delete instance ---
echo "🗑 Deleting instance $INSTANCE..."
gcloud sql instances delete $INSTANCE --project=$PROJECT --quiet
echo "✅ Instance deleted. Data safely stored in GCS."
