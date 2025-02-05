# Configuración del proveedor de Terraform
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

# Configuración del proveedor de GitHub
provider "github" {
  token = var.github_token
  owner = "ares-soluciones"
}

# Definición de variables necesarias
variable "github_token" {
  type        = string
  sensitive   = true
  description = "Token de GitHub con permisos para administrar repositorios"
}

# Definición de estructuras de datos locales
locals {
  # Lectura de archivos YAML de proyectos
  project_files = fileset("${path.module}/../repos", "*.yml")
  
  # Parseo de archivos YAML en estructura de datos
  projects = {
    for file in local.project_files :
    trimsuffix(file, ".yml") => yamldecode(file("${path.module}/../repos/${file}"))
  }

  # Aplanamiento de la estructura de repositorios
  repositories = merge([
    for project_name, project in local.projects : {
      for repo_key, repo in project :
      "${project_name}-${repo_key}" => merge(
        repo,
        {
          project_name = project_name
          full_name    = "${project_name}-${repo_key}"
        }
      )
    }
  ]...)

  # Configuraciones predeterminadas para protección de ramas
  default_branch_protection = {
    develop = {
      required_approving_review_count = 1
      enforce_admins                 = false
      allows_force_pushes           = false
      requires_status_checks        = true
    }
    testing = {
      required_approving_review_count = 2
      enforce_admins                 = false
      allows_force_pushes           = false
      requires_status_checks        = true
    }
    master = {
      required_approving_review_count = 2
      enforce_admins                 = true
      allows_force_pushes           = false
      requires_status_checks        = true
      required_linear_history       = true
    }
  }

  # Configuraciones predeterminadas para environments
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

  # Configuraciones predeterminadas para repositorios
  default_settings = {
    has_issues            = true
    has_projects          = true
    has_wiki              = true
    delete_branch_on_merge = true
    allow_squash_merge    = true
    allow_merge_commit    = false
    allow_rebase_merge    = true
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

  # Aplicación de configuraciones predeterminadas
  has_issues            = local.default_settings.has_issues
  has_projects          = local.default_settings.has_projects
  has_wiki              = local.default_settings.has_wiki
  delete_branch_on_merge = local.default_settings.delete_branch_on_merge
  allow_squash_merge    = local.default_settings.allow_squash_merge
  allow_merge_commit    = local.default_settings.allow_merge_commit
  allow_rebase_merge    = local.default_settings.allow_rebase_merge
}

# Asignación de equipos a repositorios
resource "github_team_repository" "team_access" {
  for_each = {
    for pair in flatten([
      for repo_key, repo in local.repositories : [
        for team in repo.teams : {
          repo_name = repo.name
          team     = team
          key      = "${repo.name}-${team}"
        }
      ]
    ]) : pair.key => pair
  }

  team_id    = each.value.team
  repository = github_repository.repos[each.value.repo_name].name
  permission = "push"
}

# Creación de ramas
resource "github_branch" "branches" {
  for_each = {
    for pair in flatten([
      for repo_key, repo in local.repositories : [
        for branch_name in ["develop", "testing", "master"] : {
          repo_name = repo.name
          branch    = branch_name
          key       = "${repo.name}-${branch_name}"
        }
      ]
    ]) : pair.key => pair
  }

  repository    = each.value.repo_name
  branch        = each.value.branch
  source_branch = "master"

  depends_on = [github_repository.repos]
}

# Configuración de protección de ramas
resource "github_branch_protection" "protection" {
  for_each = {
    for pair in flatten([
      for repo_key, repo in local.repositories : [
        for branch_name, protection in local.default_branch_protection : {
          repo_name = repo.name
          branch    = branch_name
          config    = protection
          key       = "${repo.name}-${branch_name}"
        }
      ]
    ]) : pair.key => pair
  }

  repository_id = github_repository.repos[each.value.repo_name].node_id
  pattern       = each.value.branch

  required_pull_request_reviews {
    required_approving_review_count = each.value.config.required_approving_review_count
  }

  enforce_admins         = each.value.config.enforce_admins
  allows_force_pushes    = each.value.config.allows_force_pushes
  required_linear_history = lookup(each.value.config, "required_linear_history", false)
  # requires_status_checks = each.value.config.requires_status_checks

  depends_on = [github_branch.branches]
}

# Creación de environments
resource "github_repository_environment" "environments" {
  for_each = {
    for pair in flatten([
      for repo_key, repo in local.repositories : [
        for env_name, env_config in local.default_environments : {
          repo_name = repo.name
          env_name  = env_name
          config    = env_config
          key       = "${repo.name}-${env_name}"
        }
      ]
    ]) : pair.key => pair
  }

  repository  = each.value.repo_name
  environment = each.value.env_name

  deployment_branch_policy {
    protected_branches     = each.value.config.deployment_branch_policy.protected_branches
    custom_branch_policies = each.value.config.deployment_branch_policy.custom_branch_policies
  }

  depends_on = [github_repository.repos]
}

# Output para depuración
output "debug_repositories" {
  value = {
    for key, repo in local.repositories :
    key => {
      name         = repo.name
      project_name = repo.project_name
      full_name    = repo.full_name
    }
  }
}