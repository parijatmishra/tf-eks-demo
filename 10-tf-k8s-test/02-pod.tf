resource "kubernetes_pod" "hello-pod" {
  metadata {
    name      = "hello-pod"
    namespace = "test"
    labels = {
      app = "hello-pod"
    }
  }

  spec {
    container {
      image = "nginx:1.17"
      name  = "httpd"
    }
  }
}
