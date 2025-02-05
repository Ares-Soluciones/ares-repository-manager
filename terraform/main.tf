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
  type      = string
  sensitive = true
}

resource "github_repository" "repo" {
  for_each    = { for dir in fileset("${path.module}/../repos", "*") : dir => dir }
  name        = each.key
  description = "Repositorio creado automáticamente"
  visibility  = "private"
  auto_init   = true
}

resource "github_branch_default" "default" {
  for_each   = github_repository.repo
  repository = each.value.name
  branch     = "master"
}

resource "github_branch_protection" "protection" {
  for_each = { for pair in setproduct(keys(github_repository.repo), ["develop", "testing", "master"]) : "${pair[0]}-${pair[1]}" => {
    repo = pair[0]
    branch = pair[1]
  }}
  
  repository_id                   = each.value.repo
  pattern                        = each.value.branch
  enforce_admins                 = false
  required_pull_request_reviews {
    required_approving_review_count = 2
  }
}

resource "github_repository_environment" "envs" {
  for_each = {
    for pair in setproduct(keys(github_repository.repo), ["dev", "test", "prod"]) : "${pair[0]}-${pair[1]}" => {
      repo = pair[0]
      env  = pair[1]
    }
  }
  
  repository  = each.value.repo
  environment = each.value.env
}