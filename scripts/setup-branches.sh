#!/bin/bash
REPO_NAME=$1

# Obtener SHA de la rama master
SHA=$(curl -s -H "Authorization: token $GH_TKN" \
  "https://api.github.com/repos/ares-soluciones/$REPO_NAME/git/ref/heads/master" | jq -r '.object.sha')

# Crear ramas develop y testing
for BRANCH in develop testing; do
  curl -X POST -H "Authorization: token $GH_TKN" \
    -d "{\"ref\": \"refs/heads/$BRANCH\", \"sha\": \"$SHA\"}" \
    "https://api.github.com/repos/ares-soluciones/$REPO_NAME/git/refs"
done