resource "google_compute_firewall" "external-iscsi" {
  name    = "kubernetes-iscsi--allow-external"
  network = "kubernetes-iscsi"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }

  source_ranges = ["0.0.0.0/0"]
  depends_on    = [google_compute_network.kubernetes-iscsi]
}

resource "google_compute_firewall" "internal-iscsi" {
  name    = "kubernetes-iscsi-allow-internal"
  network = "kubernetes-iscsi"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  source_ranges = ["10.99.99.0/24"]
  depends_on    = [google_compute_network.kubernetes-iscsi]
}
