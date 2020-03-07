resource "kubernetes_deployment" "alb-ingress-controller" {
  metadata {
    name      = "alb-ingress-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "alb-ingress-controller"
    }
  }

  spec {
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "alb-ingress-controller"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "alb-ingress-controller"
        }
      }
      spec {
        service_account_name            = kubernetes_service_account.alb-ingress-controller.metadata.0.name
        automount_service_account_token = true
        container {
          name  = "alb-ingress-controller"
          image = "docker.io/amazon/aws-alb-ingress-controller:v1.1.5"
          args  = ["--ingress-class=alb", "--cluster-name=${var.cluster_name}"]
        }
      }
    }

    strategy {
      type = "Recreate"
    }
  }
}
