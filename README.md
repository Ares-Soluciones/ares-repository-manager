# repository-manager
Repository to versioning al repository creation over de organization.

## Structure 
```
control-repo/
├── .github/
│   └── workflows/
│       └── apply.yml           # Workflow principal
├── repos/
│   └── project_1.yml           # Yml del proyecto 1 (dentro los repos asociados a ese proyecto)
│   └── project_2.yml           # Yml del proyecto 2 (dentro los repos asociados a ese proyecto)
├── terraform/
│   └── main.tf                 # Configuración central

```

