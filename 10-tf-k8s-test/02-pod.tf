resource "kubernetes_pod" "hello-pod" {
  depends_on = [kubernetes_namespace.test]
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
    resources {
      limits {
        cpu    = "0.25"
        memory = "128Mi"
      }
    }
  }
}
