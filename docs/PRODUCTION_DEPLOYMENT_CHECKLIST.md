# Maranet Zero — Production Deployment Checklist

This checklist ensures all critical steps are completed before and during production deployment.

---

## Pre-Deployment (Before Going Live)

### Environment Configuration
- [ ] **Create production `.env` file** with secure values:
  ```bash
  # Copy template and update all values
  cp .env.example .env.production
  ```
- [ ] **Generate secure secrets:**
  ```bash
  # JWT Secret (64+ characters)
  openssl rand -base64 64
  
  # Database password
  openssl rand -base64 32
  
  # Redis password
  openssl rand -base64 24
  ```
- [ ] **Update all default credentials:**
  - [ ] `JWT_SECRET` — Strong random string
  - [ ] `DATABASE_URL` — Strong password
  - [ ] `REDIS_URL` — Add password authentication
  - [ ] `GRAFANA_PASSWORD` — Strong random string
  - [ ] `MPESA_CONSUMER_KEY` — Production key from Safaricom
  - [ ] `MPESA_CONSUMER_SECRET` — Production secret from Safaricom
  - [ ] `MPESA_PASS_KEY` — Production passkey

### SSL/TLS Certificates
- [ ] **Install certbot for Let's Encrypt:**
  ```bash
  apt install certbot python3-certbot-nginx
  ```
- [ ] **Generate certificates for all domains:**
  ```bash
  # Main API
  certbot --nginx -d api.maranet.app
  
  # Bootstrap (zero-rated)
  certbot --nginx -d zero.maranet.app -d free.facebook.com.maranet.app
  
  # Monitoring (internal)
  certbot --nginx -d grafana.maranet.app
  ```
- [ ] **Verify auto-renewal:**
  ```bash
  certbot renew --dry-run
  ```

### Database Setup
- [ ] **Create production database:**
  ```sql
  CREATE DATABASE maranet;
  CREATE USER maranet WITH PASSWORD 'strong-password-here';
  GRANT ALL PRIVILEGES ON DATABASE maranet TO maranet;
  ```
- [ ] **Run migrations:**
  ```bash
  cd main-server
  DATABASE_URL="postgresql://maranet:password@localhost:5432/maranet" npx prisma migrate deploy
  ```
- [ ] **Seed initial data:**
  ```bash
  DATABASE_URL="postgresql://maranet:password@localhost:5432/maranet" npx tsx prisma/seed.ts
  ```
- [ ] **Create database backup user:**
  ```sql
  CREATE USER backup WITH REPLICATION;
  ```

### Redis Configuration
- [ ] **Set Redis password:**
  ```bash
  # Edit /etc/redis/redis.conf
  requirepass your-secure-password-here
  ```
- [ ] **Configure persistence:**
  ```bash
  save 900 1
  save 300 10
  save 60 10000
  ```
- [ ] **Restart Redis:**
  ```bash
  systemctl restart redis-server
  ```

### Firewall Configuration
- [ ] **Configure UFW:**
  ```bash
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22/tcp      # SSH
  ufw allow 80/tcp      # HTTP (for Let's Encrypt)
  ufw allow 443/tcp     # HTTPS
  ufw allow 51820/udp   # WireGuard
  ufw enable
  ```

### Monitoring Setup
- [ ] **Start Prometheus:**
  ```bash
  cd deploy
  docker compose up -d prometheus
  ```
- [ ] **Start Grafana:**
  ```bash
  docker compose up -d grafana
  ```
- [ ] **Configure Grafana datasources:**
  - [ ] Add Prometheus datasource (http://prometheus:9090)
  - [ ] Add Loki datasource (http://loki:3100)
- [ ] **Import dashboards:**
  - [ ] Node.js API dashboard
  - [ ] Gateway metrics dashboard
  - [ ] Business metrics dashboard
- [ ] **Configure Alertmanager:**
  ```yaml
  # /etc/prometheus/alertmanager.yml
  route:
    receiver: 'slack-notifications'
    group_by: ['alertname']
  
  receivers:
    - name: 'slack-notifications'
      slack_configs:
        - api_url: 'YOUR_SLACK_WEBHOOK_URL'
          channel: '#alerts'
  ```

### Backup Configuration
- [ ] **Database backup script:**
  ```bash
  # /opt/maranet/scripts/backup-db.sh
  #!/bin/bash
  DATE=$(date +%Y%m%d_%H%M%S)
  pg_dump -U maranet maranet > /backups/maranet_$DATE.sql
  # Keep only last 7 days
  find /backups -name "maranet_*.sql" -mtime +7 -delete
  ```
- [ ] **Schedule daily backups:**
  ```bash
  # crontab -e
  0 2 * * * /opt/maranet/scripts/backup-db.sh
  ```
- [ ] **Test restore procedure:**
  ```bash
  psql -U maranet maranet < /backups/maranet_YYYYMMDD_HHMMSS.sql
  ```

---

## Deployment Steps

### 1. Infrastructure Deployment
```bash
# Deploy using Ansible
cd deploy/ansible

# Deploy API server
ansible-playbook -i inventory/hosts.yml playbooks/deploy-api.yml \
  --extra-vars "db_password=SECURE_PASSWORD jwt_secret=SECURE_JWT_SECRET"

# Deploy Gateway
ansible-playbook -i inventory/hosts.yml playbooks/deploy-gateway.yml \
  --extra-vars "wg_address=10.0.0.1/16 wg_listen_port=51820 external_interface=eth0"
```

### 2. Start Services
```bash
# Using Docker Compose (if using containerized deployment)
cd deploy
docker compose up -d

# Verify all services are running
docker compose ps

# Check logs
docker compose logs -f main-server
```

### 3. Verify Deployment
```bash
# Health check
curl https://api.maranet.app/health

# Expected response:
# {"success":true,"data":{"status":"healthy","service":"maranet-api","version":"1.0.0","uptime":...}}

# Test authentication
curl -X POST https://api.maranet.app/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"254700000000"}'

# Test bootstrap API
curl https://zero.maranet.app/ping

# Expected response:
# {"status":"ok","timestamp":"..."}
```

### 4. Monitor Deployment
- [ ] Check Prometheus metrics: http://grafana.maranet.app:9090
- [ ] Check Grafana dashboards: https://grafana.maranet.app
- [ ] Verify all alerts are firing correctly
- [ ] Monitor logs for errors

---

## Post-Deployment

### Immediate Verification (First 24 Hours)
- [ ] **Monitor error rates** — Should be < 1%
- [ ] **Check response times** — Should be < 500ms average
- [ ] **Verify M-Pesa integration** — Test a real payment
- [ ] **Check WireGuard connectivity** — Test VPN connection
- [ ] **Monitor resource usage** — CPU, memory, disk

### Ongoing Maintenance
- [ ] **Daily:**
  - [ ] Check backup completion
  - [ ] Review error logs
  - [ ] Monitor active subscriptions
  
- [ ] **Weekly:**
  - [ ] Review system metrics
  - [ ] Check certificate expiry
  - [ ] Review reseller node health
  
- [ ] **Monthly:**
  - [ ] Security updates
  - [ ] Database optimization
  - [ ] Performance review
  - [ ] Backup restore test

### Incident Response
- [ ] **Create runbook for common issues:**
  - [ ] API down → Check systemd service, restart if needed
  - [ ] Database issues → Check connections, run vacuum
  - [ ] WireGuard issues → Check interface, restart service
  - [ ] M-Pesa failures → Check credentials, network connectivity

---

## Rollback Procedure

If deployment fails, follow these steps:

1. **Stop new services:**
   ```bash
   systemctl stop maranet-api
   systemctl stop maranet-gateway
   ```

2. **Restore previous version:**
   ```bash
   # If using git
   cd /opt/maranet
   git checkout PREVIOUS_COMMIT_HASH
   npm run build
   systemctl start maranet-api
   ```

3. **Restore database (if needed):**
   ```bash
   # Find latest backup before deployment
   psql -U maranet maranet < /backups/maranet_YYYYMMDD_HHMMSS.sql
   ```

4. **Verify rollback:**
   ```bash
   curl https://api.maranet.app/health
   ```

---

## Contact Information

### Emergency Contacts
- **DevOps Lead:** [Name] - [Phone]
- **Backend Lead:** [Name] - [Phone]
- **On-Call Engineer:** [Name] - [Phone]

### External Services
- **Safaricom M-Pesa Support:** [Contact]
- **Hosting Provider:** [Contact]
- **Domain Registrar:** [Contact]

---

## Checklist Completion

- [ ] All pre-deployment items completed
- [ ] All deployment steps executed successfully
- [ ] All post-deployment verifications passed
- [ ] Monitoring and alerting configured
- [ ] Backup procedures tested
- [ ] Team briefed on incident response

**Deployment Date:** _______________  
**Deployed By:** _______________  
**Approved By:** _______________