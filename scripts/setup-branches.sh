#!/bin/bash
REPO_NAME=$1

# Obtener SHA de la rama production
SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/tu-organizacion/$REPO_NAME/git/ref/heads/production" | jq -r '.object.sha')

# Crear ramas develop y testing
for BRANCH in develop testing; do
  curl -X POST -H "Authorization: token $GITHUB_TOKEN" \
    -d "{\"ref\": \"refs/heads/$BRANCH\", \"sha\": \"$SHA\"}" \
    "https://api.github.com/repos/tu-organizacion/$REPO_NAME/git/refs"
done