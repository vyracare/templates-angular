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
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
      S3_BUCKET_NAME: ${{ secrets.S3_BUCKET_NAME }}
      CLOUDFRONT_ID: ${{ secrets.CLOUDFRONT_ID }}
      AWS_REGION: ${{ secrets.AWS_REGION }}
      PAT_TOKEN: ${{ secrets.PAT_TOKEN }}
EOF

  cat > .github/workflows/pr-to-release.yml <<'EOF'
name: PR TO RELEASE

on:
  push:
    branches:
      - develop

permissions:
  contents: read
  id-token: write

jobs:
  publish-dev:
    uses: vyracare/vyracare-infra-pipes-angular/.github/workflows/cd-angular.yml@main
    with:
      branch-name: ${{ github.ref_name }}
      codeartifact-domain: vyracare-design-system
      codeartifact-repo: vyracare-design-system
      codeartifact-domain-owner: '510253726006'
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
      S3_BUCKET_NAME: ${{ secrets.S3_BUCKET_NAME }}
      CLOUDFRONT_ID: ${{ secrets.CLOUDFRONT_ID }}
      AWS_REGION: ${{ secrets.AWS_REGION }}
      PAT_TOKEN: ${{ secrets.PAT_TOKEN }}

  create-release-branch:
    name: Create versioned release branch
    runs-on: ubuntu-latest
    needs: publish-dev
    outputs:
      branch: ${{ steps.release_branch.outputs.branch }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false
          token: ${{ secrets.PAT_TOKEN }}

      - name: Create or reuse release branch
        id: release_branch
        run: |
          set -euo pipefail
          RELEASE_BRANCH="release/v$(date -u +%Y.%m.%d).${GITHUB_RUN_NUMBER}"
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git remote set-url origin "https://x-access-token:${{ secrets.PAT_TOKEN }}@github.com/${GITHUB_REPOSITORY}.git"
          git fetch origin main develop
          if git ls-remote --heads origin "$RELEASE_BRANCH" | grep -q "$RELEASE_BRANCH"; then
            git checkout -B "$RELEASE_BRANCH" "origin/$RELEASE_BRANCH"
          else
            git checkout -B "$RELEASE_BRANCH" "origin/main"
            git push -u origin "$RELEASE_BRANCH"
          fi
          echo "branch=$RELEASE_BRANCH" >> $GITHUB_OUTPUT

  open-pr-release:
    name: Open Pull Request to versioned release
    runs-on: ubuntu-latest
    needs: create-release-branch
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false
          token: ${{ secrets.PAT_TOKEN }}

      - name: Open Pull Request to release
        uses: repo-sync/pull-request@v2
        with:
          github_token: ${{ secrets.PAT_TOKEN }}
          source_branch: develop
          destination_branch: ${{ needs.create-release-branch.outputs.branch }}
          pr_title: "PR automatic develop into ${{ needs.create-release-branch.outputs.branch }}"
          pr_body: |
            PR automatica criada pelo pipeline.
            Branch de origem: `develop`
            Destino: `${{ needs.create-release-branch.outputs.branch }}`
EOF

  cat > .github/workflows/pr-to-main.yml <<'EOF'
name: PR TO MAIN

on:
  push:
    branches:
      - release
      - 'release/**'

permissions:
  contents: read
  id-token: write

jobs:
  detect-release-diff:
    name: Detect release diff against main
    runs-on: ubuntu-latest
    outputs:
      should_run: ${{ steps.release_diff.outputs.should_run }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false
          token: ${{ secrets.PAT_TOKEN }}

      - name: Detect whether release branch is ahead of main
        id: release_diff
        run: |
          set -euo pipefail
          git fetch origin main "${{ github.ref_name }}"
          git checkout -B "${{ github.ref_name }}" "origin/${{ github.ref_name }}"
          ahead_count=$(git rev-list --count origin/main..HEAD)
          echo "ahead_count=$ahead_count" >> $GITHUB_OUTPUT
          if [ "$ahead_count" -gt 0 ]; then
            echo "should_run=true" >> $GITHUB_OUTPUT
          else
            echo "should_run=false" >> $GITHUB_OUTPUT
          fi

  ci-angular:
    name: Run CI for release
    needs: detect-release-diff
    if: needs.detect-release-diff.outputs.should_run == 'true'
    uses: vyracare/vyracare-infra-pipes-angular/.github/workflows/ci-angular.yml@main
    with:
      branch-name: ${{ github.ref_name }}
      codeartifact-domain: vyracare-design-system
      codeartifact-repo: vyracare-design-system
      codeartifact-domain-owner: '510253726006'
      aws-region: us-east-1
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}

  publish-hml:
    name: Publish release to HML
    needs:
      - detect-release-diff
      - ci-angular
    if: needs.detect-release-diff.outputs.should_run == 'true'
    uses: vyracare/vyracare-infra-pipes-angular/.github/workflows/cd-angular.yml@main
    with:
      branch-name: ${{ github.ref_name }}
      codeartifact-domain: vyracare-design-system
      codeartifact-repo: vyracare-design-system
      codeartifact-domain-owner: '510253726006'
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
      S3_BUCKET_NAME: ${{ secrets.S3_BUCKET_NAME }}
      CLOUDFRONT_ID: ${{ secrets.CLOUDFRONT_ID }}
      AWS_REGION: ${{ secrets.AWS_REGION }}
      PAT_TOKEN: ${{ secrets.PAT_TOKEN }}

  open-pr-main:
    name: Open Pull Request to main
    runs-on: ubuntu-latest
    needs:
      - detect-release-diff
      - publish-hml
    if: needs.detect-release-diff.outputs.should_run == 'true'
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false
          token: ${{ secrets.PAT_TOKEN }}

      - name: Open Pull Request to main
        uses: repo-sync/pull-request@v2
        with:
          github_token: ${{ secrets.PAT_TOKEN }}
          source_branch: ${{ github.ref_name }}
          destination_branch: main
          pr_title: "PR automatic ${{ github.ref_name }} into main"
          pr_body: |
            PR automatica criada pelo pipeline.
            Branch de origem: `${{ github.ref_name }}`
            Destino: `main`
EOF
fi

echo "Projeto renomeado com sucesso para $NEW_NAME"
