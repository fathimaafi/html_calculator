terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# --- VARIABLES ---
variable "gcp_project" { type = string }
variable "gcp_region" {
  type    = string
  default = "us-central1"
}
variable "gcp_zone" {
  type    = string
  default = "us-central1-f"
}

# --- PROVIDERS ---
provider "google" {
  project     = var.gcp_project
  region      = var.gcp_region
  zone        = var.gcp_zone
}

# --- IMPORT EXISTING VM ---
import {
  to = google_compute_instance.existing_web_server
  id = "projects/${var.gcp_project}/zones/${var.gcp_zone}/instances/firstvmmachinedockernode"
}

# --- VM INSTANCE CONFIGURATION ---
resource "google_compute_instance" "existing_web_server" {
  name         = "firstvmmachinedockernode" # Must match your real VM name
  machine_type = "e2-medium"              # Must match your real machine type
  zone         = "us-central1-f"
  tags         = ["http-server", "https-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-minimal-2404-lts-amd64"   # Must match your real OS image
    }
  }

  network_interface {
    network = "default" # Must match your existing VPC network name
    access_config {
      # Leaves public IP config intact
    }
  }

  service_account {
    email  = "194579763637-compute@developer.gserviceaccount.com"
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }

  metadata = {
    "enable-osconfig" = "FALSE"
    "ssh-keys"        = <<EOT
hp:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDgScPYZTuTfCpxs4l2V4D1feDU42YfWcKA2eSAej1c9jaEB9SqjcaQ7rFnYGfb9diHN8REZ6xp1+oBQzahKGDGOG+o9a6qHOtgLzvcutLNggtPkwax0G9xSCC95g1UtOfV9sJlYu7ZZjvmp5EKl/Y0gml2scZUTHODJ3XC5jGcbcF/84/gENnltO7IvhEz3E2v9+m8eyr/qNdUtfd+EYsrIgAu1h/nfF0ti4hpORilfjNQ8jxtSHqvhD8v1wu5UwgYXPOlvq0EnNVBEL05Ma1l7wEyETio3sf5niin6iEIKksoNQRPhYyfJoO7Ap1o31qIqLUxwHb92JvGI1hw2yIf5wjseLf5GG02KorXR+hgZhDrw0TjUBdaRJGR30WYdwiRQ0T2iyh0W7KZU8FheDiASaMO1lzj3RdcCL46dwiX1M+Jr1T3HRNERpicq7UjpZOjwQP9zvBu+Xd2kJOwo+AmcTCaszCvne7tG9+qlf9uWXo0RFOH9hyWjVH5M6y2WLlgDDtoWGDcaXVRiZDVSlKO0qQ1vtTuUTLQlNc3rnGlln5d1x44G/bCGyWDQFtq5hLlRtwr99qEX7pgvADfLH6Q/cgnHBN9bJsJUwnKPDBOGdqCQGcNJp7i/XkKXbdluvTeyY/nXq41xFesPM6dZap9IUcqgg/0aFEEm0NsYVNzwQ== hp@MKAFI
github-actions-deploy:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFBieXNnGaMaDGJmtJtRsJV8MkW2qRnmgn5um2Bmt3uzEY5fA8xHHBTV6woZjgZqkjTnP2Ze6QbPQG8MjKowfhw2yabkmda1V3V+9crkZZ/aBe0eLPzhRjkxqUAJw2BFeNU6sbdKEG065Foj8RyQRKnteqHNe3MqJLqrKYq6itJ3f6GFGcG9JKHrZm7qsJ5QiByG7ZlQyY9eaKWCGYyZkAttaQOA3N0rtAaV+fbizOYZQEQIdwrdIK7Ytw4ZHwm5BXZnbLsaHKxp5noIZRY/kdANaHFEXsBcsDu1NYXvbOiA6L6d3B3AKb/pamN0+x3EqnpthNNuhcRkEBnNlXqxyRTOGwMz0HzntwwM+tN0BWuJg1V7ZhjA0XMSLN35TzsMSvTp342ngiviHSEMufb0qm5nevY4+AE/pPoY3maB6ZzPZD0rL3GjxxqcYSeftb7nV+Mqu/Kcq8qO5qZbLApdfSUAoicu0kQLYvYkx2p0Y7bRWTp7jkh6KyvCnCF7OoMtFwE22/DGfd+/QijAts5WuilO5G6f3YsKmyDARyySKLUJmpPC/9fXDtqeK1nVVlY8r0cB4LJcjACzKjdAlEPJQEkusAfgwAqI1DkTwwlqUYwbMr62UMqCEXAhkNMXj5MTQ8SZzQPNpSttOuQqY8gFaDxPC0qFLqsKz/Ik9H2BaFsw== github-actions-deploy
fathima_afi876:ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLaHE8j9D/R+ituzlIk0G/B3XQRgon/uVENpXdR+LvPIhBx8bgXicP5p3QnK8jCqXZZxx64BMG09oEoFIgHK66c= google-ssh {"userName":"fathima.afi876@gmail.com","expireOn":"2026-06-08T11:28:33+0000"}
fathima_afi876:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCUJDzaqFgJN4/+FK+fXy7CcOgglXGjquRowDFzVg6a0pTp3U7kut25zxYUEj8/vhDK+6WycHy4M64Wmxl86b1XDCChfjd8pw1xs7uTy3ep77XgrkqcVZfi0BgCLOgXgZo4fCEE0dpkW8FwVxGMxKcvDj0R9K2kAWPj+KxJ+9bPZJP/SJwjnSSAlwnQ9xn7+wD9c5ZAVAvpu/RH3izD9JQ2TilSFDHVDN/A2oDmErD2+BGwf5CoOaAd5nnzc4phLfiuYtSa7/eGBHXFYZA22lN7BTyD039cwSlRfxmdEeA/EbKqYcdZ3lme5puXFZ9HSmgdc3+AzUEDU1fK4jCdN1hx google-ssh {"userName":"fathima.afi876@gmail.com","expireOn":"2026-06-08T11:28:41+0000"}
EOT
  }
}
