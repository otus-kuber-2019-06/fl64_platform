
resource "google_compute_network" "kubernetes-iscsi" {
  name                    = "kubernetes-iscsi"
  auto_create_subnetworks = "false"
}


resource "google_compute_subnetwork" "kubernetes-iscsi" {
  name          = "kubernetes-iscsi"
  ip_cidr_range = "10.99.99.0/24"
  network       = "kubernetes-iscsi"
  depends_on    = [google_compute_network.kubernetes-iscsi]
}
