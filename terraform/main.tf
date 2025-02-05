# terraform/main.tf

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

# Variables necesarias
variable "github_token" {
  type        = string
  sensitive   = true
  description = "Token de GitHub con permisos para administrar repositorios"
}

# Función local para leer y parsear los archivos YAML
locals {
  # Lee todos los archivos YAML en el directorio repos
  repo_files = fileset("${path.module}/../repos", "*.yml")
  
  # Parsea cada archivo YAML y crea un mapa de configuraciones
  repo_configs = {
    for file in local.repo_files :
    trimsuffix(file, ".yml") => yamldecode(file("${path.module}/../repos/${file}"))
  }
}

# Creación de repositorios
resource "github_repository" "repos" {
  for_each    = local.repo_configs
  
  name        = each.value.name
  description = each.value.description
  visibility  = each.value.visibility
  auto_init   = true
  topics      = each.value.topics

  # Configuraciones adicionales que podrían ser útiles
  has_issues    = true
  has_projects  = true
  has_wiki      = true
}

# Creación de ramas
resource "github_branch" "branch" {
  for_each = {
    for pair in flatten([
      for repo_name, repo in local.repo_configs : [
        for branch in ["develop", "testing", "master"] : {
          repo   = repo_name
          branch = branch
        }
      ]
    ]) : "${pair.repo}-${pair.branch}" => pair
  }

  repository = github_repository.repos[each.value.repo].name
  branch     = each.value.branch
  source_branch = "master"
}

# Configuración de branch protection
resource "github_branch_protection" "protection" {
  for_each = {
    for pair in flatten([
      for repo_name, repo in local.repo_configs : [
        for branch, config in repo.branch_protection : {
          repo   = repo_name
          branch = branch
          config = config
        }
      ]
    ]) : "${pair.repo}-${pair.branch}" => pair
  }

  repository_id = github_repository.repos[each.value.repo].node_id
  pattern       = each.value.branch
  
  required_pull_request_reviews {
    required_approving_review_count = each.value.config.required_approving_review_count
  }
  
  enforce_admins = false
}

# Creación de environments
resource "github_repository_environment" "environment" {
  for_each = {
    for pair in flatten([
      for repo_name, repo in local.repo_configs : [
        for env_name, env in repo.environments : {
          repo = repo_name
          env  = env_name
          config = env
        }
      ]
    ]) : "${pair.repo}-${pair.env}" => pair
  }

  repository  = github_repository.repos[each.value.repo].name
  environment = each.value.env
}

# Configuración de secrets para cada environment
resource "github_actions_environment_secret" "env_secrets" {
  for_each = {
    for secret in flatten([
      for repo_name, repo in local.repo_configs : [
        for env_name, env in repo.environments : [
          for secret_name, secret_value in env.secrets : {
            repo = repo_name
            env  = env_name
            name = secret_name
            value = secret_value
          }
        ]
      ]
    ]) : "${secret.repo}-${secret.env}-${secret.name}" => secret
  }

  repository       = github_repository.repos[each.value.repo].name
  environment      = each.value.env
  secret_name     = each.value.name
  plaintext_value = each.value.value
}