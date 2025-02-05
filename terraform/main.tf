# terraform/main.tf

terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

# Variables necesarias
variable "github_token" {
  type        = string
  sensitive   = true
  description = "Token de GitHub con permisos para administrar repositorios"
}

provider "github" {
  owner = "ares-soluciones"
  token = var.github_token
}

# Variables y configuraciones predeterminadas
locals {
  # Lee todos los archivos YAML de proyectos
  project_files = fileset("${path.module}/../repos", "*.yml")
  
  # Parsea cada archivo YAML de proyecto
  projects = {
    for file in local.project_files :
    trimsuffix(file, ".yml") => yamldecode(file("${path.module}/../repos/${file}"))
  }

  # Aplanar la estructura de repositorios para facilitar su procesamiento
  repositories = merge([
    for project_name, project in local.projects : {
      for repo_key, repo in project : repo_key => merge(repo, {
        project_name = project_name
      })
    }
  ]...)

  # Configuraciones predeterminadas para todos los repositorios
  default_branch_protection = {
    develop = {
      required_approving_review_count = 1
      enforce_admins                  = false
      allow_force_pushes              = false
      require_status_checks           = true
    }
    testing = {
      required_approving_review_count = 2
      enforce_admins                  = false
      allow_force_pushes              = false
      require_status_checks           = true
    }
    master = {
      required_approving_review_count = 2
      enforce_admins                  = true
      allow_force_pushes              = false
      require_status_checks           = true
      required_linear_history         = true
    }
  }

  default_environments = {
    dev = {
      deployment_branch_policy = {
        protected_branches     = false
        custom_branch_policies = true
      }
    }
    test = {
      deployment_branch_policy = {
        protected_branches     = true
        custom_branch_policies = false
      }
    }
    prod = {
      deployment_branch_policy = {
        protected_branches     = true
        custom_branch_policies = false
      }
    }
  }

  default_settings = {
    has_issues             = true
    has_projects           = true
    has_wiki               = true
    delete_branch_on_merge = true
    allow_squash_merge     = true
    allow_merge_commit     = false
    allow_rebase_merge     = true
  }
}

# Creación de repositorios
resource "github_repository" "repos" {
  for_each = local.repositories

  name        = each.value.name
  description = each.value.description
  visibility  = each.value.visibility
  topics      = each.value.topics
  auto_init   = true

  dynamic "template" {
    for_each = lookup(each.value, "template", null) != null ? [each.value.template] : []
    content {
      owner      = template.value.owner
      repository = template.value.repository
    }
  }

  # Aplicar configuraciones predeterminadas
  has_issues             = local.default_settings.has_issues
  has_projects           = local.default_settings.has_projects
  has_wiki               = local.default_settings.has_wiki
  delete_branch_on_merge = local.default_settings.delete_branch_on_merge
  allow_squash_merge     = local.default_settings.allow_squash_merge
  allow_merge_commit     = local.default_settings.allow_merge_commit
  allow_rebase_merge     = local.default_settings.allow_rebase_merge
}

# Asignación de equipos
resource "github_team_repository" "team_access" {
  for_each = {
    for access in flatten([
      for repo_key, repo in local.repositories : [
        for team in repo.teams : {
          repo_key = repo_key
          team     = team
        }
      ]
    ]) : "${access.repo_key}-${access.team}" => access
  }

  team_id    = each.value.team
  repository = github_repository.repos[each.value.repo_key].name
  permission = "push"  # Puedes ajustar el nivel de permiso según necesites
}

# Creación de ramas
resource "github_branch" "branches" {
  for_each = {
    for branch in flatten([
      for repo_key, repo in local.repositories : [
        for branch_name in ["develop", "testing", "master"] : {
          repo_key = repo_key
          branch   = branch_name
        }
      ]
    ]) : "${repo_key}-${branch.branch}" => branch
  }

  repository = github_repository.repos[each.value.repo_key].name
  branch     = each.value.branch
  source_branch = "master"
}

# Protección de ramas
resource "github_branch_protection" "protection" {
  for_each = {
    for protection in flatten([
      for repo_key, repo in local.repositories : [
        for branch_name, protection in local.default_branch_protection : {
          repo_key = repo_key
          branch   = branch_name
          config   = protection
        }
      ]
    ]) : "${protection.repo_key}-${protection.branch}" => protection
  }

  repository_id = github_repository.repos[each.value.repo_key].node_id
  pattern       = each.value.branch

  required_pull_request_reviews {
    required_approving_review_count = each.value.config.required_approving_review_count
  }

  enforce_admins = each.value.config.enforce_admins
  allows_force_pushes = each.value.config.allow_force_pushes
  # require_linear_history = lookup(each.value.config, "required_linear_history", false)
}

# Creación de environments
resource "github_repository_environment" "environments" {
  for_each = {
    for env in flatten([
      for repo_key, repo in local.repositories : [
        for env_name, env_config in local.default_environments : {
          repo_key = repo_key
          env_name = env_name
          config   = env_config
        }
      ]
    ]) : "${env.repo_key}-${env.env_name}" => env
  }

  repository  = github_repository.repos[each.value.repo_key].name
  environment = each.value.env_name

  deployment_branch_policy {
    protected_branches     = each.value.config.deployment_branch_policy.protected_branches
    custom_branch_policies = each.value.config.deployment_branch_policy.custom_branch_policies
  }
}