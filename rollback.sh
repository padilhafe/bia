#!/bin/bash

# Rollback Simples - Projeto BIA
# Faz rollback para uma versão específica

set -e

# Configurações
ECR_REGISTRY="689517797857.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPO="bia"
CLUSTER="bia"
SERVICE="service-bia"
TASK_FAMILY="task-def-bia"
REGION="us-east-1"

# Verificar parâmetro
if [ -z "$1" ]; then
    echo "Uso: $0 <commit-hash>"
    echo ""
    echo "Versões disponíveis:"
    aws ecr describe-images \
        --repository-name $ECR_REPO \
        --region $REGION \
        --query 'sort_by(imageDetails,&imagePushedAt)[-10:][*].[imageTags[0],imagePushedAt]' \
        --output table
    exit 1
fi

TARGET_HASH=$1
IMAGE_TAG="$ECR_REGISTRY/$ECR_REPO:$TARGET_HASH"

echo "=== Rollback para $TARGET_HASH ==="

# Verificar se imagem existe
if ! aws ecr describe-images --repository-name $ECR_REPO --region $REGION --image-ids imageTag=$TARGET_HASH >/dev/null 2>&1; then
    echo "❌ Imagem $TARGET_HASH não encontrada no ECR"
    exit 1
fi

# Obter task definition atual
TASK_DEF=$(aws ecs describe-task-definition --task-definition $TASK_FAMILY --region $REGION --query 'taskDefinition')

# Criar nova task definition com imagem de rollback
NEW_TASK_DEF=$(echo $TASK_DEF | jq --arg image "$IMAGE_TAG" '
  .containerDefinitions[0].image = $image |
  del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)
')

# Registrar nova task definition
echo "$NEW_TASK_DEF" > /tmp/rollback-task-def.json
NEW_REVISION=$(aws ecs register-task-definition --region $REGION --cli-input-json file:///tmp/rollback-task-def.json --query 'taskDefinition.revision' --output text)
rm -f /tmp/rollback-task-def.json

# Atualizar serviço
aws ecs update-service \
  --region $REGION \
  --cluster $CLUSTER \
  --service $SERVICE \
  --task-definition $TASK_FAMILY:$NEW_REVISION

echo "✅ Rollback concluído!"
echo "Versão: $TARGET_HASH"
echo "Task Definition: $TASK_FAMILY:$NEW_REVISION"
