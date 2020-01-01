resource "kubernetes_deployment" "hello-dep" {
  metadata {
    name      = "hello-dep"
    namespace = "test"
    labels = {
      app = "hello-dep"
    }
  }

  spec {
    replicas = 3
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
              cpu    = "0.5"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}
