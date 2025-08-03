# CI/CD Pipeline Documentation

## Overview
The CI/CD pipeline is implemented using GitHub Actions and provides automated testing, building, and deployment of the multi-service web application.

## Pipeline Architecture

### Workflow Triggers
- **Pull Request**: Triggers testing jobs only
- **Push to main**: Triggers full pipeline (test → build → deploy)
- **Manual**: Can be triggered manually from GitHub Actions tab

### Pipeline Stages

#### 1. Test Stage
**Purpose**: Validate code quality and syntax
**Runs on**: Every PR and main branch push
**Duration**: ~2-3 minutes

```yaml
test:
  runs-on: ubuntu-latest
  steps:
    - Checkout code
    - Setup Python 3.11
    - Install Python dependencies
    - Syntax check Python app
    - Setup Node.js 18
    - Install Node.js dependencies
    - Syntax check Node.js app
```

#### 2. Build Stage
**Purpose**: Create Docker images
**Runs on**: After successful tests
**Duration**: ~3-5 minutes

```yaml
build:
  needs: test
  runs-on: ubuntu-latest
  steps:
    - Checkout code
    - Build Python Docker image
    - Build Node.js Docker image
```

#### 3. Deploy Stage
**Purpose**: Deploy to AWS infrastructure
**Runs on**: Only on main branch after successful build
**Duration**: ~8-12 minutes

```yaml
deploy:
  needs: [test, build]
  runs-on: ubuntu-latest
  if: github.ref == 'refs/heads/main'
  environment: production
  steps:
    - Configure AWS credentials
    - Setup SSH key
    - Setup Terraform
    - Install Ansible
    - Run automated deployment script
```

## Required Secrets

### GitHub Repository Secrets
Configure these in: `Settings → Secrets and variables → Actions`

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS programmatic access key | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key | `wJalrXUt...` |
| `SSH_PRIVATE_KEY` | Private SSH key content | `-----BEGIN OPENSSH PRIVATE KEY-----...` |

### Secret Setup Commands
```bash
# Generate and display SSH private key
cat ~/.ssh/devops-key

# Get AWS credentials (if using AWS CLI)
aws configure list
```

## Pipeline Validation

### 1. Testing CI/CD Pipeline

#### Create Test Branch
```bash
# Create feature branch
git checkout -b feature/test-pipeline

# Make a test change
echo "# Test change $(date)" >> test-file.md
git add test-file.md
git commit -m "Test: Validate CI/CD pipeline"
git push origin feature/test-pipeline
```

#### Create Pull Request
1. Go to GitHub repository
2. Click "Compare & pull request"
3. Create PR from `feature/test-pipeline` to `main`
4. Observe that only **test** job runs
5. Verify tests pass before merging

#### Merge to Main
1. Merge the pull request
2. Observe full pipeline execution:
   - ✅ Test job completes
   - ✅ Build job completes
   - ✅ Deploy job completes
3. Verify deployment success

### 2. Pipeline Monitoring

#### GitHub Actions Interface
```bash
# Using GitHub CLI
gh workflow list
gh run list --limit 10
gh run view <run-id>

# View logs
gh run view <run-id> --log
```

#### Pipeline Status Checks
```bash
# After deployment, verify services
WEB_IP=$(cd terraform && terraform output -raw web_server_ip)
PROXY_IP=$(cd terraform && terraform output -raw proxy_server_ip)

# Test deployed applications
curl -k https://$PROXY_IP/api/python/
curl -k https://$PROXY_IP/api/node/

# Check deployment logs
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "sudo docker-compose -f /opt/devops-app/docker-compose.yml logs --tail=20"
```

## Deployment Process

### Automated Deployment Script
The pipeline uses `deploy.sh` which performs:

1. **Prerequisites Check**
   - Verifies required tools (terraform, ansible, docker, jq)
   - Validates AWS credentials

2. **Infrastructure Provisioning**
   - Creates S3 bucket for Terraform state
   - Runs `terraform init` and `terraform apply`
   - Captures server IP addresses

3. **Configuration Management**
   - Updates Ansible inventory with server IPs
   - Runs Ansible playbook to configure servers
   - Deploys applications and monitoring stack

4. **Validation**
   - Tests application endpoints
   - Verifies monitoring services
   - Displays access URLs

### Manual Deployment Trigger
```bash
# Trigger deployment manually
git commit --allow-empty -m "Manual deployment trigger"
git push origin main
```

## Pipeline Customization

### Environment-Specific Deployments

#### Staging Environment
```yaml
deploy-staging:
  if: github.ref == 'refs/heads/develop'
  environment: staging
  steps:
    - name: Deploy to staging
      run: |
        export TF_VAR_environment=staging
        ./deploy.sh
```

#### Production Environment
```yaml
deploy-production:
  if: github.ref == 'refs/heads/main'
  environment: production
  needs: [test, build]
  steps:
    - name: Deploy to production
      run: ./deploy.sh
```

### Adding Quality Gates

#### Code Quality Checks
```yaml
quality:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3
    - name: Run linting
      run: |
        pip install flake8
        flake8 app-python/
        npm install -g eslint
        eslint app-nodejs/
```

#### Security Scanning
```yaml
security:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3
    - name: Run security scan
      uses: github/super-linter@v4
      env:
        DEFAULT_BRANCH: main
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Rollback Strategy

### Automatic Rollback
```bash
# In deploy.sh, add health check and rollback
if ! curl -k https://$PROXY_IP/api/python/ | grep -q "Hello"; then
  echo "Deployment failed, rolling back..."
  git revert HEAD --no-edit
  git push origin main
  exit 1
fi
```

### Manual Rollback
```bash
# Rollback to previous commit
git log --oneline -5
git revert <commit-hash>
git push origin main

# Or rollback infrastructure
cd terraform
terraform apply -target=aws_instance.web_server -var="ami_id=<previous-ami>"
```

## Monitoring Pipeline Health

### Pipeline Metrics
- **Success Rate**: Target >95%
- **Build Time**: Target <15 minutes
- **Deployment Frequency**: Track daily/weekly deployments
- **Mean Time to Recovery**: Target <30 minutes

### Alerting Setup
```yaml
# Add to workflow for Slack notifications
- name: Notify on failure
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: failure
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Best Practices

### Security
- ✅ Use GitHub secrets for sensitive data
- ✅ Limit deployment to main branch only
- ✅ Use environment protection rules
- ✅ Rotate AWS credentials regularly
- ✅ Use least-privilege IAM policies

### Performance
- ✅ Cache dependencies between runs
- ✅ Parallelize independent jobs
- ✅ Use matrix builds for multiple environments
- ✅ Optimize Docker image layers

### Reliability
- ✅ Add comprehensive health checks
- ✅ Implement automatic rollback on failure
- ✅ Use infrastructure as code for consistency
- ✅ Test pipeline changes in feature branches

## Troubleshooting

### Common Pipeline Failures

#### 1. AWS Credentials Issues
```bash
# Error: "Unable to locate credentials"
# Solution: Check GitHub secrets configuration
```

#### 2. Terraform State Lock
```bash
# Error: "Error locking state"
# Solution: Force unlock or wait for timeout
terraform force-unlock <lock-id>
```

#### 3. SSH Connection Failures
```bash
# Error: "Permission denied (publickey)"
# Solution: Verify SSH private key in secrets
```

#### 4. Ansible Playbook Failures
```bash
# Error: "UNREACHABLE"
# Solution: Check security groups and SSH connectivity
```

### Debug Pipeline Issues
```bash
# Enable debug logging in workflow
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true

# Check runner logs
gh run view <run-id> --log
```

## Pipeline Evolution

### Future Enhancements
1. **Multi-environment support** (dev/staging/prod)
2. **Blue-green deployments** for zero downtime
3. **Automated testing** with integration tests
4. **Security scanning** with SAST/DAST tools
5. **Performance testing** in pipeline
6. **Infrastructure drift detection**
7. **Cost optimization** with resource scheduling

### Metrics and KPIs
- Deployment frequency
- Lead time for changes
- Mean time to recovery
- Change failure rate
- Pipeline success rate
- Build duration trends