resource "google_compute_instance" "controllers" {
  count          = 1
  name           = "controller${count.index}"
  machine_type   = "n1-standard-2"
  zone           = var.region_zone
  can_ip_forward = true

  tags = ["kubernetes-the-hard-way", "controller"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1604-lts"
      size  = "200"
    }
  }

  network_interface {
    subnetwork = "kubernetes"
    network_ip    = "10.240.0.1${count.index}"
    access_config {
      # Ephemeral external IP
    }
  }

  network_interface {
    subnetwork = "kubernetes-iscsi"
    network_ip    = "10.99.99.1${count.index}"
  }


  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  depends_on = [google_compute_subnetwork.kubernetes,google_compute_subnetwork.kubernetes-iscsi]
}

resource "google_compute_instance" "workers" {
  count          = 3
  name           = "worker${count.index}"
  machine_type   = "n1-standard-1"
  zone           = var.region_zone
  can_ip_forward = true

  tags = ["kubernetes-the-hard-way", "worker"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
      size  = "200"
    }
  }

  network_interface {
    subnetwork = "kubernetes"
    network_ip    = "10.240.0.2${count.index}"
    access_config {
      # Ephemeral external IP
    }
  }

  network_interface {
    subnetwork = "kubernetes-iscsi"
    network_ip    = "10.99.99.2${count.index}"
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  depends_on = [google_compute_subnetwork.kubernetes,google_compute_subnetwork.kubernetes-iscsi]
}

resource "google_compute_instance" "storage" {
  count          = 1
  name           = "storage${count.index}"
  machine_type   = "n1-standard-1"
  zone           = var.region_zone
  can_ip_forward = true

  tags = ["storage"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
      size  = "200"
    }
  }

  network_interface {
    subnetwork = "kubernetes-iscsi"
    network_ip    = "10.99.99.10${count.index}"
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  depends_on = [google_compute_subnetwork.kubernetes-iscsi]
}
