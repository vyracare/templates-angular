#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Uso: ./rename-angular-project.sh <novo-nome>"
  exit 1
fi

NEW_NAME="$1"
GENERIC_NAME="\[name-generic\]"
NEW_NAME_UNDERSCORE=$(echo "$NEW_NAME" | tr '-' '_')

echo "Renomeando projeto para: $NEW_NAME"

FILES=("angular.json" "package.json" "nx.json" "tsconfig.json")

for FILE in "${FILES[@]}"; do
  if [ -f "$FILE" ]; then
    echo "Atualizando $FILE..."
    sed -i "s/$GENERIC_NAME/$NEW_NAME/g" "$FILE"
  fi
done

if [ -f webpack.config.js ]; then
  echo "Atualizando webpack.config.js..."
  sed -i "s/$GENERIC_NAME/$NEW_NAME_UNDERSCORE/g" webpack.config.js
fi

if [ -d "src/app" ]; then
  find src/app -type f -exec sed -i "s/$GENERIC_NAME/$NEW_NAME/g" {} +
fi

if [ -d "projects/[name-generic]" ]; then
  echo "Renomeando pasta projects/[name-generic] para projects/$NEW_NAME"
  mv "projects/[name-generic]" "projects/$NEW_NAME"
fi

grep -rl "\[name-generic\]" . | while read -r file; do
  echo "Corrigindo import em $file"
  sed -i "s/$GENERIC_NAME/$NEW_NAME/g" "$file"
done

if [ -d ".github/workflows" ]; then
  cat > .github/workflows/publish.yml <<'EOF'
name: PUBLISH

on:
  push:
    branches:
      - develop
      - release
      - 'release/**'
      - main

permissions:
  contents: read
  id-token: write

jobs:
  publish:
    uses: vyracare/vyracare-infra-pipes-angular/.github/workflows/cd-angular.yml@main
    with:
      branch-name: ${{ github.ref_name }}
      codeartifact-domain: vyracare-design-system
      codeartifact-repo: vyracare-design-system
      codeartifact-domain-owner: '510253726006'
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      S3_BUCKET_NAME: ${{ secrets.S3_BUCKET_NAME }}
      CLOUDFRONT_ID: ${{ secrets.CLOUDFRONT_ID }}
      AWS_REGION: ${{ secrets.AWS_REGION }}
      PAT_TOKEN: ${{ secrets.PAT_TOKEN }}
EOF
fi

echo "Projeto renomeado com sucesso para $NEW_NAME"
