#!/bin/bash

# Deploy Versionado Simples - Projeto BIA
# Rotina complementar para deploy com versionamento por commit hash

set -e

# Configurações
ECR_REGISTRY="689517797857.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPO="bia"
CLUSTER="bia"
SERVICE="service-bia"
TASK_FAMILY="task-def-bia"
REGION="us-east-1"

# Obter commit hash (7 caracteres)
COMMIT_HASH=$(git rev-parse --short=7 HEAD)
IMAGE_TAG="$ECR_REGISTRY/$ECR_REPO:$COMMIT_HASH"

echo "=== Deploy Versionado BIA ==="
echo "Commit Hash: $COMMIT_HASH"
echo "Image Tag: $IMAGE_TAG"
echo "=========================="

# 1. Login ECR
echo "1. Fazendo login no ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# 2. Build da imagem
echo "2. Build da imagem..."
docker build -t bia:$COMMIT_HASH .
docker tag bia:$COMMIT_HASH $IMAGE_TAG

# 3. Push para ECR
echo "3. Push para ECR..."
docker push $IMAGE_TAG

# 4. Obter task definition atual
echo "4. Obtendo task definition atual..."
TASK_DEF=$(aws ecs describe-task-definition --task-definition $TASK_FAMILY --region $REGION --query 'taskDefinition')

# 5. Criar nova task definition
echo "5. Criando nova task definition..."
NEW_TASK_DEF=$(echo $TASK_DEF | jq --arg image "$IMAGE_TAG" '
  .containerDefinitions[0].image = $image |
  del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)
')

# 6. Registrar nova task definition
echo "6. Registrando nova task definition..."
echo "$NEW_TASK_DEF" > /tmp/new-task-def.json
NEW_REVISION=$(aws ecs register-task-definition --region $REGION --cli-input-json file:///tmp/new-task-def.json --query 'taskDefinition.revision' --output text)
rm -f /tmp/new-task-def.json

echo "Nova task definition: $TASK_FAMILY:$NEW_REVISION"

# 7. Atualizar serviço
echo "7. Atualizando serviço ECS..."
aws ecs update-service \
  --region $REGION \
  --cluster $CLUSTER \
  --service $SERVICE \
  --task-definition $TASK_FAMILY:$NEW_REVISION

echo "=== Deploy Concluído ==="
echo "Versão: $COMMIT_HASH"
echo "Task Definition: $TASK_FAMILY:$NEW_REVISION"
echo "======================="
