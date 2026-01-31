#!/bin/bash

# Análise Pré-Deploy - Projeto BIA
# Verifica o que será feito antes do deploy

set -e

# Configurações
ECR_REGISTRY="689517797857.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPO="bia"
CLUSTER="bia"
SERVICE="service-bia"
TASK_FAMILY="task-def-bia"
REGION="us-east-1"

# Obter commit hash
COMMIT_HASH=$(git rev-parse --short=7 HEAD)
IMAGE_TAG="$ECR_REGISTRY/$ECR_REPO:$COMMIT_HASH"

echo "=== ANÁLISE PRÉ-DEPLOY ==="
echo "Data/Hora: $(date)"
echo "=========================="

# 1. Informações do Git
echo "1. INFORMAÇÕES DO GIT:"
echo "   Commit Hash: $COMMIT_HASH"
echo "   Commit Message: $(git log -1 --pretty=format:'%s')"
echo "   Author: $(git log -1 --pretty=format:'%an')"
echo "   Date: $(git log -1 --pretty=format:'%ad')"
echo ""

# 2. Verificar se imagem já existe
echo "2. VERIFICAÇÃO DE IMAGEM:"
if aws ecr describe-images --repository-name $ECR_REPO --region $REGION --image-ids imageTag=$COMMIT_HASH >/dev/null 2>&1; then
    echo "   ⚠️  Imagem $COMMIT_HASH JÁ EXISTE no ECR"
    echo "   Será sobrescrita no deploy"
else
    echo "   ✅ Imagem $COMMIT_HASH é NOVA"
fi
echo "   Image URI: $IMAGE_TAG"
echo ""

# 3. Status atual do serviço
echo "3. STATUS ATUAL DO SERVIÇO:"
CURRENT_TASK_DEF=$(aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $REGION --query 'services[0].taskDefinition' --output text)
CURRENT_IMAGE=$(aws ecs describe-task-definition --task-definition $CURRENT_TASK_DEF --region $REGION --query 'taskDefinition.containerDefinitions[0].image' --output text)
RUNNING_COUNT=$(aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $REGION --query 'services[0].runningCount' --output text)
DESIRED_COUNT=$(aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $REGION --query 'services[0].desiredCount' --output text)

echo "   Task Definition Atual: $CURRENT_TASK_DEF"
echo "   Imagem Atual: $CURRENT_IMAGE"
echo "   Tasks Rodando: $RUNNING_COUNT/$DESIRED_COUNT"
echo ""

# 4. Últimas versões no ECR
echo "4. ÚLTIMAS VERSÕES NO ECR:"
aws ecr describe-images \
    --repository-name $ECR_REPO \
    --region $REGION \
    --query 'sort_by(imageDetails,&imagePushedAt)[-5:][*].[imageTags[0],imagePushedAt]' \
    --output table
echo ""

# 5. O que será feito
echo "5. O QUE SERÁ FEITO NO DEPLOY:"
echo "   ✅ Build da imagem com tag: $COMMIT_HASH"
echo "   ✅ Push para ECR: $IMAGE_TAG"
echo "   ✅ Criar nova task definition baseada em: $CURRENT_TASK_DEF"
echo "   ✅ Atualizar serviço: $SERVICE"
echo "   ✅ Nova imagem será: $IMAGE_TAG"
echo ""

# 6. Verificações de segurança
echo "6. VERIFICAÇÕES:"
if [ -f "Dockerfile" ]; then
    echo "   ✅ Dockerfile encontrado"
else
    echo "   ❌ Dockerfile NÃO encontrado"
fi

if git diff --quiet; then
    echo "   ✅ Working directory limpo"
else
    echo "   ⚠️  Existem mudanças não commitadas"
    echo "   Arquivos modificados:"
    git status --porcelain | head -5
fi

echo ""
echo "=========================="
echo "Para executar o deploy:"
echo "./deploy-versioned.sh"
echo "=========================="
