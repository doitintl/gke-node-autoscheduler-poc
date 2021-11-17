locals {
  gke_cluster_name = var.cluster_name == "" || var.cluster_name == null ? "${var.project_id}-gke-cluster" : var.cluster_name
  default_node_pool_name = var.default_node_pool_name == "" || var.default_node_pool_name == null ? "default-node-pool" : var.default_node_pool_name
  gpu_node_pool_name = var.gpu_node_pool_name == "" || var.gpu_node_pool_name == null ? "gpu-node-pool" : var.gpu_node_pool_name
}

resource "google_service_account" "gke_default_node_service_account" {
  provider      = google-beta
  project       = var.project_id
  account_id    = "gke-default-sa-id"
  display_name  = "gke-default-node-sa"
}

resource "google_service_account" "gke_gpu_node_service_account" {
  provider      = google-beta
  project       = var.project_id
  account_id    = "gke-gpu-node-sa-id"
  display_name  = "gke-gpu-node-sa"
}

resource "google_container_cluster" "primary" {
  provider  = google-beta
  project   = var.project_id
  name      = local.gke_cluster_name
  location  = var.project_region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  addons_config {
    http_load_balancing {
      disabled = true
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  cluster_autoscaling {
    enabled             = true
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
    resource_limits {
      resource_type = "cpu"
      minimum = 0
      maximum = 20
    }
    resource_limits {
      resource_type = "memory"
      minimum = 0
      maximum = 132
    }
    auto_provisioning_defaults {
      service_account = google_service_account.gke_gpu_node_service_account.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }
}

resource "google_container_node_pool" "primary_node_pool" {
  provider    = google-beta
  project     = var.project_id
  name        = local.default_node_pool_name
  location    = var.project_region
  cluster     = google_container_cluster.primary.name

  node_count  = var.default_node_pool_min_node_count

  autoscaling {
    min_node_count    = var.default_node_pool_min_node_count
    max_node_count    = var.default_node_pool_max_node_count
  }
  node_config {
    preemptible  = var.default_node_pool_preemptible
    machine_type = var.default_node_pool_machine_type
    metadata = {
      disable-legacy-endpoints = "true"
    }
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_default_node_service_account.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ]
  }
}

resource "google_container_node_pool" "gpu_node_pool" {
  provider    = google-beta
  project     = var.project_id
  name        = local.gpu_node_pool_name
  location    = var.project_region
  cluster     = google_container_cluster.primary.name

  autoscaling {
    min_node_count    = var.gpu_node_pool_min_node_count
    max_node_count    = var.gpu_node_pool_max_node_count
  }

  management {
    auto_repair       = true
    auto_upgrade      = true
  }

  upgrade_settings {
    max_surge         = 2
    max_unavailable   = 2
  }

  initial_node_count  = var.gpu_node_pool_initial_node_count

  node_config {
    preemptible  = var.gpu_node_pool_preemptible
    machine_type = var.gpu_node_pool_machine_type
    image_type    = "COS"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_gpu_node_service_account.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/compute",
    ]

    // Just for testing without require GPU resource
    // taint = [
    //   {
    //     key       = "dedicated"
    //     value     = "gpu"
    //     effect    = "NO_SCHEDULE"
    //   },
    // ]

    node_locations      = ["australia-southeast1-b"]
    guest_accelerator {
      type  = "nvidia-tesla-p4"
      count = 1
    }
  }
}

data "google_container_cluster" "cluster" {
  project   = var.project_id
  name      = local.gke_cluster_name
  location  = var.project_region
}

data "google_client_config" "provider" {}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.cluster.endpoint}"
  token                  = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth[0].cluster_ca_certificate)
}

resource "null_resource" "gpu-driver" {

  depends_on = [
    google_container_cluster.primary
  ]

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials --region=${var.project_region} ${local.gke_cluster_name}"
  }

  provisioner "local-exec" {
    command    = "kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded.yaml"
  }

}
