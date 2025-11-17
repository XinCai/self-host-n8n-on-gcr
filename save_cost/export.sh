# Set variables
PROJECT="uplifted-woods-459110-i5"
INSTANCE="n8n-db"
DB_NAME="postgres"
BUCKET="my-sql-backups-bucket"
EXPORT_FILE="n8n-db-$(date +%Y%m%d).sql.gz"

# 1️⃣ Ensure Cloud SQL service account has permission
PROJECT_NUMBER=$(gcloud projects describe $PROJECT --format="value(projectNumber)")
EXPORT_SA="service-${PROJECT_NUMBER}@gcp-sa-cloud-sql.iam.gserviceaccount.com"

gcloud storage buckets add-iam-policy-binding gs://$BUCKET \
  --member="serviceAccount:$EXPORT_SA" \
  --role="roles/storage.objectAdmin" \
  --project=$PROJECT

sleep 10  # wait for IAM propagation

# 2️⃣ Export database to GCS bucket
gcloud sql export sql $INSTANCE gs://$BUCKET/$EXPORT_FILE \
  --database=$DB_NAME \
  --project=$PROJECT

# 3️⃣ Download exported file locally
gsutil cp gs://$BUCKET/$EXPORT_FILE ./
