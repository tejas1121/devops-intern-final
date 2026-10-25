# Deploys the image built and published by CI (.github/workflows/ci.yml).
# Run with:  nomad job run -var="image_tag=<commit-sha>" nomad/nginx-app.nomad.hcl

variable "image_repo" {
  type        = string
  description = "GHCR repository the CI pipeline pushes to"
  default     = "ghcr.io/tejas1121/devops-intern-final"
}

variable "image_tag" {
  type        = string
  description = "Image tag to deploy; use the commit SHA, not latest"
}

job "nginx-app" {
  datacenters = ["dc1"]
  type        = "service"

  # Rolling deployment: replace one allocation at a time and roll back automatically
  # if the new version never passes its Consul health check.
  update {
    max_parallel     = 1
    health_check     = "checks"
    min_healthy_time = "10s"
    healthy_deadline = "2m"
    auto_revert      = true
  }

  group "web" {
    count = 1

    network {
      # Dynamic host port, mapped to the container's port 8080.
      port "http" {
        to = 8080
      }
    }

    # Restart in place a few times before giving up on this node...
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # ...then let Nomad reschedule the allocation, backing off exponentially.
    reschedule {
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "5m"
      unlimited      = true
    }

    service {
      name     = "nginx-app"
      port     = "http"
      provider = "consul"
      tags     = ["web", "nginx"]

      check {
        name     = "healthz"
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "${var.image_repo}:${var.image_tag}"
        ports = ["http"]
      }

      # 100 MHz / 64 MB as specified; a static NGINX site idles at a few MB of RAM.
      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
