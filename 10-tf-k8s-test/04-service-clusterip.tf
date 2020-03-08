resource "kubernetes_service" "hello-svc" {
  metadata {
    name      = "hello-svc"
    namespace = "test"
    labels = {
      app = "hello-svc"
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.hello-svc.spec[0].selector[0].match_labels.app
    }
    session_affinity = "ClientIP"

    port {
      port        = 8080
      target_port = 80
    }

    type = "ClusterIP"
  }

}
resource "kubernetes_deployment" "hello-svc" {
  depends_on = [kubernetes_namespace.test]
  metadata {
    name      = "hello-svc"
    namespace = "test"
    labels = {
      app = "hello-svc"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "hello-svc"
      }
    }

    template {
      metadata {
        namespace = "test"
        labels = {
          app = "hello-svc"
        }
      }

      spec {
        container {
          image = "nginx:1.17"
          name  = "httpd"
          port {
            container_port = 80
          }
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
