terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "github" {
  owner = "ares-soluciones"
  token = var.github_token
}

variable "github_token" {
  sensitive = true
}

# Crear repositorio con 'master' como default branch
resource "github_repository" "repo" {
  for_each      = { for dir in fileset("${path.module}/../repos", "*") : dir => dir }
  name          = each.key
  description   = "Repositorio creado automáticamente"
  private       = true
  auto_init     = true
  default_branch= "master"
}

# Protección de ramas (develop, testing, master)
resource "github_branch_protection" "main" {
  for_each      = github_repository.repo
  repository_id = each.value.name

  dynamic "pattern" {
    for_each = ["develop", "testing", "master"]
    content {
      name             = pattern.value
      enforce_admins   = false
      required_reviews {
        required_approving_review_count = 2
      }
    }
  }
}

# Crear environments
resource "github_repository_environment" "envs" {
  for_each    = toset(["dev", "test", "prod"])
  repository  = github_repository.repo[each.key].name
  environment = each.value
}