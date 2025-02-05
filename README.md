# repository-manager
Repository to versioning al repository creation over de organization.

## Structure 
```
control-repo/
├── .github/
│   └── workflows/
│       └── apply.yml            # Workflow principal
├── repos/
│   └── mi-nuevo-repo/          # Directorio con nombre del repo
│       └── config.yml          # Config específica (opcional)
├── terraform/
│   ├── main.tf                 # Configuración central
│   ├── branch_creator.tf       # Módulo para crear ramas
│   └── environment_secrets.tf  # Módulo para secrets
└── scripts/
    ├── setup-branches.sh       # Crea ramas vía API
    └── set-secrets.sh          # Configura secrets en environments

```

