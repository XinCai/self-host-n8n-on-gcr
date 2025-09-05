# This script updates the Cloud Run Docker image for n8n, rebuilds it, and redeploys it to Google Cloud Run.
export PROJECT_ID="uplifted-woods-459110-i5"
export REGION="asia-southeast1"  # Choose your preferred region
export AR_REPO_NAME="allie-n8n" 

# Pull the latest n8n image
docker pull n8nio/n8n:latest

# Rebuild your custom image
docker build --platform linux/amd64 -t $REGION-docker.pkg.dev/$PROJECT_ID/$AR_REPO_NAME/n8n:latest .

## make sure you use the correct gcloud account
gcloud auth list
gcloud config set account hufuqishe688@gmail.com

# Push to your artifact registry
docker push $REGION-docker.pkg.dev/$PROJECT_ID/$AR_REPO_NAME/n8n:latest

#===== this is commented out, command doesn't work, use the n8n.yaml file to redeploy =====
# Redeploy your Cloud Run service
# gcloud run services update n8n \
#     --image=$REGION-docker.pkg.dev/$PROJECT_ID/$AR_REPO_NAME/n8n:latest \
#     --region=$REGION  \
#     --startup-probe=tcp:5678,initial-delay=120s,period=10s,timeout=5s,failure-threshold=3

#=== use the n8n.yaml file to redeploy, this step works ===
### 
### make sure you have this 
### ERROR: (gcloud.run.services.replace) service.spec.template.spec.containers[0].startup_probe.timeout_seconds: must be less than period_seconds.
### This is fixed in the n8n.yaml file below
        # startupProbe:
        #   failureThreshold: 3
        #   initialDelaySeconds: 120
        #   periodSeconds: 130
        #   tcpSocket:
        #     port: 5678
        #   timeoutSeconds: 120
## 
# n8n.yaml is exported from the command below
gcloud run services describe n8n --region="asia-southeast1"  --format export > n8n.yaml
# after editing the n8n.yaml file, run the command below to update the service
# Make sure to edit the n8n.yaml file to point to the new image
# and set the correct environment variables
gcloud run services replace n8n.yaml --region=$REGION
