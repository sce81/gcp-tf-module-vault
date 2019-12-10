resource "google_service_account" "vault_admin" {
  count        = var.service_account_enabled
  account_id   = "${var.name}-cluster-admin-sa"
  display_name = "${var.project} ${var.name} service account"
  project      = var.project
}

resource "google_service_account_key" "vault-key" {
  count              = var.service_account_enabled
  service_account_id = google_service_account.vault_admin[0].name
}

resource "google_project_iam_member" "vault-cluster-admin-sa" {
  count   = var.service_account_enabled
  project = var.project
  role    = "roles/viewer"
  member  = "serviceAccount:${local.service_account_email}"
}

#resource "google_project_iam_member" "other-service-account" {
#    count                       = "${var.external_account_enabled}"
#    project                     = "${var.project}"
#    role                        = "roles/viewer"
#    member                      = "serviceAccount:${var.service_account_email}"
#    
#}

resource "google_compute_region_instance_group_manager" "vault" {
  provider = google-beta
  name     = "${var.project}-${var.cluster_name}-group-manager"

  project = var.project

  base_instance_name = var.cluster_name
  region             = var.region

  version {
    name              = "${var.project}-${var.name}"
    instance_template = data.template_file.compute_instance_template_self_link.rendered
  }

    update_policy{
        type = "PROACTIVE"
        minimal_action = "REPLACE"
        max_surge_percent = 20
        max_unavailable_fixed = 2
        min_ready_sec = 50
    }
  # Restarting a Vault server has an important consequence: The Vault server has to be manually unsealed again. Therefore,
  # the update strategy used to roll out a new GCE Instance Template must be a rolling update. But since Terraform does
  # not yet support ROLLING_UPDATE, such updates must be manually rolled out for now.

  target_pools = [google_compute_target_pool.vault.self_link]
  target_size  = var.cluster_size

  depends_on = [google_compute_instance_template.vault_private]
}

resource "google_compute_instance_template" "vault_public" {
#### Public Instance Group to be used during testing.
    count                       = var.create_public # create boolean 

    name                        = "${var.project}-${var.name}-pub-template-${var.templateversion}"
    description                 = "${var.cluster_description}"
    project                     = "${var.project}"

    instance_description        = "${var.cluster_description}"
    machine_type                = "${var.machine_type}"

    tags                        = "${concat(list(var.cluster_tag_name), var.custom_tags)}"
    metadata_startup_script     = var.user_data
    metadata                    = "${merge(map(var.metadata_key_name_for_cluster_size, var.cluster_size), var.custom_metadata)}"


    scheduling {
        automatic_restart       = "true"
        on_host_maintenance     = "MIGRATE"
        preemptible             = "false"
    }

    disk {
        boot                    = true
        auto_delete             = true
        source_image            = "${var.vault_image}"
        disk_size_gb            = "${var.root_disk_size}"
        disk_type               = "${var.root_disk_type}"
    }

    network_interface {
        network                 = "${var.subnetwork_name != "" ? "" : var.network}"
        subnetwork              = "${var.subnetwork_name != "" ? var.subnetwork_name : ""}"
        subnetwork_project      = "${var.project != "" ? var.project : var.project}"
  
    access_config {
   #   nat_ip                    = "${var.nat_ip}"
    }   
    }

service_account {
    email                       = local.service_account_email

    # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
    # force an interpolation expression to be interpreted as a list by wrapping it
    # in an extra set of list brackets. That form was supported for compatibilty in
    # v0.11, but is no longer supported in Terraform v0.12.
    #
    # If the expression in the following list itself returns a list, remove the
    # brackets to avoid interpretation as a list of lists. If the expression
    # returns a single list item then leave it as-is and remove this TODO comment.
    scopes = [
          "https://www.googleapis.com/auth/userinfo.email",
          "https://www.googleapis.com/auth/compute",
          "https://www.googleapis.com/auth/devstorage.read_write",
          "https://www.googleapis.com/auth/cloud-platform",
          "https://www.googleapis.com/auth/logging.write",
    ]
    
  }
    labels   = {
        name                    = "${var.name}"
        project                 = "${var.project}"
    }
    lifecycle {
        create_before_destroy = true
    }
}

resource "google_compute_instance_template" "vault_private" {
  count = var.create_private # create boolean

  name        = "${var.project}-${var.name}-pri-template-${var.templateversion}"
  description = var.cluster_description
  project     = var.project

  tags                    = concat([var.cluster_tag_name], var.custom_tags)
  instance_description    = var.cluster_description
  machine_type            = var.machine_type
  metadata_startup_script = var.user_data
  metadata = merge(
    {
      "${var.metadata_key_name_for_cluster_size}" = "var.cluster_size"
    },
    var.custom_metadata,
  )

  scheduling {
    automatic_restart   = "true"
    on_host_maintenance = "MIGRATE"
    preemptible         = "false"
  }

  disk {
    boot         = true
    auto_delete  = true
    source_image = var.vault_image
    disk_size_gb = var.root_disk_size
    disk_type    = var.root_disk_type
  }

  service_account {
    email = local.service_account_email

    # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
    # force an interpolation expression to be interpreted as a list by wrapping it
    # in an extra set of list brackets. That form was supported for compatibilty in
    # v0.11, but is no longer supported in Terraform v0.12.
    #
    # If the expression in the following list itself returns a list, remove the
    # brackets to avoid interpretation as a list of lists. If the expression
    # returns a single list item then leave it as-is and remove this TODO comment.
    scopes = [
          "https://www.googleapis.com/auth/userinfo.email",
          "https://www.googleapis.com/auth/compute",
          "https://www.googleapis.com/auth/devstorage.read_write",
          "https://www.googleapis.com/auth/cloud-platform",
          "https://www.googleapis.com/auth/logging.write",
    ]
    
  }
  labels = {
    name        = var.name
    projectironment = var.project
  }

  network_interface {
    subnetwork = var.subnetwork_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_firewall" "cluster_internal_firewall" {
  name    = "${var.cluster_name}-internal-firewall"
  network = var.network
  project = var.project

  allow {
    protocol = "tcp"
    ports    = [var.cluster_port]
  }
  source_tags = [var.cluster_tag_name]
  target_tags = [var.cluster_tag_name]
}

resource "google_compute_firewall" "cluster_api_firewall" {
  name    = "${var.cluster_name}-api-firewall"
  network = var.network
  project = var.project

  allow {
    protocol = "tcp"
    ports    = [var.api_port]
  }

  source_ranges = var.inbound_api_cidr
  #    source_tags                 = ["${var.cluster_tag_name}"]
  #    target_tags                 = ["${var.cluster_tag_name}"]
}

resource "google_compute_firewall" "allow_inbound_health_check" {
  count = var.enable_web_proxy

  name    = "${var.cluster_name}-lb-health-check"
  network = var.network

  project = var.project

  allow {
    protocol = "tcp"
    ports    = [var.health_check_port]
  }

  source_ranges = concat(["130.211.0.0/22", "35.191.0.0/16"])
  target_tags   = [var.cluster_tag_name]
}

resource "google_storage_bucket" "vault_storage_backend" {
  name          = "${var.project}-${var.cluster_name}-backend-storage"
  location      = var.backend_location
  storage_class = var.storage_class
  project       = var.project

  force_destroy = var.bucket_force_destroy

  labels = {
    name        = var.name
    projectironment = var.project
  }
}

resource "google_storage_bucket_acl" "vault_storage_backend" {
  bucket         = google_storage_bucket.vault_storage_backend.name
  predefined_acl = var.bucket_acl
}

resource "google_storage_bucket_iam_binding" "external_service_acc_binding" {
  count  = var.use_external_service_account
  bucket = "${var.cluster_name}-backend-storage"
  role   = "/roles/storage.objectAdmin"

  members = [
    "serviceAccount:${local.service_account_email}",
  ]

  depends_on = [
    google_storage_bucket.vault_storage_backend,
    google_storage_bucket_acl.vault_storage_backend,
  ]
}

resource "google_storage_bucket_iam_binding" "vault_cluster_admin_service_acc_binding" {
  count  = var.create_service_account
  bucket = "${var.cluster_name}-backend-storage"
  role   = "roles/storage.objectAdmin"

  members = [
    "serviceAccount:${google_service_account.vault_admin[0].email}",
  ]

  depends_on = [
    google_storage_bucket.vault_storage_backend,
    google_storage_bucket_acl.vault_storage_backend,
  ]
}

data "template_file" "compute_instance_template_self_link" {
  template = element(
    concat(google_compute_instance_template.vault_public.*.self_link),
    0,
  )
}

locals {
  service_account_email = var.create_service_account == 1 ? element(concat(google_service_account.vault_admin.*.email, [""]), 0) : var.service_account_email
}

## Load Balancer

resource "google_compute_forwarding_rule" "vault" {
  name = "${var.cluster_name}-forwarding-rule"

  #ip_address                   = "${var.forwarding_rule_ip_address}"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"

  # network                       = "${var.network}"
  port_range = var.api_port
  target     = google_compute_target_pool.vault.self_link
}

resource "google_compute_target_pool" "vault" {
  name             = "${var.cluster_name}-target-pool"
  description      = "${var.project} ${var.name} Target Pool"
  session_affinity = var.target_pool_session_affinity
  health_checks    = [google_compute_http_health_check.vault.name]
}

resource "google_compute_http_health_check" "vault" {
  name                = "${var.cluster_name}-health-check"
  description         = "${var.project} ${var.name} Health Check"
  check_interval_sec  = var.lb_health_check_interval_sec
  timeout_sec         = var.lb_health_check_timeout_sec
  healthy_threshold   = var.lb_health_check_healthy_threshold
  unhealthy_threshold = var.lb_health_check_unhealthy_threshold

  port         = var.lb_health_check_port
  request_path = var.lb_health_check_path
}

resource "google_compute_firewall" "load_balancer" {
  name        = "${var.cluster_name}-rule-lb"
  description = "${var.project} ${var.name} Load Balancer Health Check Firewall"
  network     = var.network == "" ? "default" : var.network

  allow {
    protocol = "tcp"
    ports    = [var.api_port]
  }

  # "130.211.0.0/22" - Enable inbound traffic from the Google Cloud Load Balancer (https://goo.gl/xULu8U)
  # "35.191.0.0/16" - Enable inbound traffic from the Google Cloud Health Checkers (https://goo.gl/xULu8U)
  # "0.0.0.0/0" - Enable any IP address to reach our nodes
  source_ranges = concat(["130.211.0.0/22", "35.191.0.0/16"], var.lb_ingress_ips)

  target_tags = [var.cluster_tag_name]
}

