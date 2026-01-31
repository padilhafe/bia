# Deploy Versionado - Projeto BIA

Scripts complementares para deploy com versionamento baseado em commit hash.

## Scripts Disponíveis

### 1. `analyze-deploy.sh` - Análise Pré-Deploy
Analisa o que será feito antes do deploy executar.

```bash
./analyze-deploy.sh
```

**Mostra:**
- Informações do commit atual
- Se a imagem já existe no ECR
- Status atual do serviço ECS
- Últimas versões no ECR
- O que será feito no deploy
- Verificações de segurança

### 2. `deploy-versioned.sh` - Deploy Versionado
Executa o deploy com versionamento por commit hash.

```bash
./deploy-versioned.sh
```

**Processo:**
1. Obtém commit hash atual (7 caracteres)
2. Build da imagem com tag do commit
3. Push para ECR
4. Cria nova task definition
5. Atualiza serviço ECS

### 3. `rollback.sh` - Rollback Simples
Faz rollback para uma versão específica.

```bash
# Ver versões disponíveis
./rollback.sh

# Rollback para versão específica
./rollback.sh abc1234
```

## Workflow Recomendado

1. **Antes do deploy:**
   ```bash
   ./analyze-deploy.sh
   ```

2. **Executar deploy:**
   ```bash
   ./deploy-versioned.sh
   ```

3. **Se necessário, rollback:**
   ```bash
   ./rollback.sh <commit-hash>
   ```

## Versionamento

- Cada deploy cria uma nova task definition
- Imagens são taggeadas com commit hash (7 caracteres)
- Histórico completo no ECR para rollbacks
- Task definitions numeradas sequencialmente

## Configurações

Scripts configurados para:
- **ECR:** `689517797857.dkr.ecr.us-east-1.amazonaws.com/bia`
- **Cluster:** `bia`
- **Service:** `service-bia`
- **Task Family:** `task-def-bia`
- **Region:** `us-east-1`

## Dependências

- AWS CLI configurado
- Docker instalado
- jq instalado
- Git repository

## Scripts Existentes

Estes scripts complementam (não substituem):
- `deploy.sh` - Deploy simples existente
- `deploy-ecs.sh` - Deploy completo com mais opções
- `build.sh` - Build básico
