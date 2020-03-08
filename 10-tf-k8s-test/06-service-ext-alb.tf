locals {
  name = "game2048-ext-alb"
}

resource "kubernetes_deployment" "game2048-ext-alb" {
  depends_on = [kubernetes_namespace.test]
  metadata {
    name      = local.name
    namespace = "test"
    labels = {
      app = local.name
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = local.name
      }
    }
    template {
      metadata {
        name      = local.name
        namespace = "test"
        labels = {
          app = local.name
        }
      }
      spec {
        container {
          image = "alexwhen/docker-2048"
          name  = "game2048"
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

resource "kubernetes_service" "game2048-ext-alb" {
  metadata {
    name      = "game2048-ext-alb"
    namespace = "test"
    labels = {
      app = "game2048-ext-alb"
    }
  }

  spec {
    type = "NodePort"
    selector = {
      app = kubernetes_deployment.game2048-ext-alb.spec.0.selector.0.match_labels.app
    }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_ingress" "game2048-ext-alb" {
  metadata {
    name      = local.name
    namespace = "test"
    labels = {
      app = local.name
    }
    annotations = {
      "kubernetes.io/ingress.class"      = "alb"
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
    }
  }
  spec {
    rule {
      http {
        path {
          path = "/*"
          backend {
            service_name = kubernetes_service.game2048-ext-alb.metadata.0.name
            service_port = kubernetes_service.game2048-ext-alb.spec.0.port.0.port
          }
        }
      }
    }
  }
}
