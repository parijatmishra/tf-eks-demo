resource "kubernetes_deployment" "hello-dep" {
  depends_on = [kubernetes_namespace.test]
  metadata {
    name      = "hello-dep"
    namespace = "test"
    labels = {
      app = "hello-dep"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "hello-dep-pod"
      }
    }

    template {
      metadata {
        namespace = "test"
        labels = {
          app = "hello-dep-pod"
        }
      }

      spec {
        container {
          image = "nginx:1.17"
          name  = "httpd"

          resources {
            limits {
              cpu    = "0.25"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}
