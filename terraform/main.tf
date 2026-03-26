terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.6.0"
    }
  }
}

provider "google" {
  credentials = file("../google_credentials.json")
  project     = "zoomcamp-project-491223" 
  region      = "us-central1"
}

# 1. Create the Data Lake Bucket 
resource "google_storage_bucket" "data-lake-bucket" {
  name          = "zoomcamp-project-491223-league-bucket" 
  location      = "US"
  force_destroy = true
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}

# 2. Create the Data Warehouse Dataset
resource "google_bigquery_dataset" "raw_dataset" {
  dataset_id                 = "league_data_raw"
  location                   = "US"
  delete_contents_on_destroy = true
}