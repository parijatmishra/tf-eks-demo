resource "kubernetes_service" "hello-int-nlb" {
  metadata {
    name      = "hello-int-nlb"
    namespace = "test"
    labels = {
      app = "hello-int-nlb"
    }
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"     = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-internal" = "0.0.0.0/0"
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.hello-int-nlb.spec[0].selector[0].match_labels.app
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }

}
resource "kubernetes_deployment" "hello-int-nlb" {
  depends_on = [kubernetes_namespace.test]
  metadata {
    name      = "hello-int-nlb"
    namespace = "test"
    labels = {
      app = "hello-int-nlb"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "hello-int-nlb"
      }
    }

    template {
      metadata {
        namespace = "test"
        labels = {
          app = "hello-int-nlb"
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
