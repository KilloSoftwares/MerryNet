# Maranet Zero — Security Hardening Guide

This guide outlines security measures to implement before production deployment.

---

## 1. Secrets Management

### Generate Strong Secrets
```bash
# JWT Secret (64+ characters)
openssl rand -base64 64

# Database Password (32+ characters)
openssl rand -base64 32

# Redis Password (24+ characters)
openssl rand -base64 24

# M-Pesa Pass Key
openssl rand -base64 32
```

### Store Secrets Securely
- [ ] **Never commit secrets to version control**
- [ ] **Use environment variables** for all sensitive data
- [ ] **Add `.env` to `.gitignore`**
- [ ] **Use a secrets manager** (HashiCorp Vault, AWS Secrets Manager) for production
- [ ] **Rotate secrets regularly** (every 90 days recommended)

---

## 2. Database Security

### PostgreSQL Hardening
```sql
-- 1. Use strong passwords
ALTER USER maranet WITH PASSWORD 'strong-random-password';

-- 2. Restrict connections to localhost only (modify pg_hba.conf)
-- local   all   all   peer
-- host    all   all   127.0.0.1/32   md5
-- host    all   all   ::1/128        md5

-- 3. Enable SSL
-- In postgresql.conf:
-- ssl = on
-- ssl_cert_file = '/path/to/server.crt'
-- ssl_key_file = '/path/to/server.key'

-- 4. Limit connection attempts
-- In postgresql.conf:
-- authentication_timeout = 1min
-- log_connections = on
-- log_disconnections = on
-- log_min_error_statement = error

-- 5. Create read-only user for monitoring
CREATE USER monitor WITH PASSWORD 'strong-password';
GRANT pg_monitor TO monitor;
```

### Regular Database Maintenance
```bash
# Update statistics
vacuumdb --all --analyze

# Reindex periodically
reindexdb --all

# Check for unused indexes
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan;
```

---

## 3. Redis Security

### Configure Authentication
```bash
# /etc/redis/redis.conf
requirepass your-very-secure-password-here

# Bind to localhost only
bind 127.0.0.1

# Disable dangerous commands
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command CONFIG ""
rename-command EVAL ""

# Enable protected mode
protected-mode yes

# Set max clients
maxclients 10000
```

### Network Security
```bash
# Only allow local connections via firewall
ufw deny 6379
ufw allow from 127.0.0.1 to any port 6379
```

---

## 4. Network Security

### Firewall Configuration (UFW)
```bash
# Reset to defaults
ufw reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (consider changing port)
ufw allow 22/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow WireGuard
ufw allow 51820/udp

# Enable logging
ufw logging on

# Enable firewall
ufw enable

# Check status
ufw status verbose
```

### Fail2ban Configuration
```bash
# /etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = auto

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-limit-req]
enabled = true
port = http,https
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 5
```

---

## 5. TLS/SSL Configuration

### Nginx SSL Hardening
```nginx
# /etc/nginx/conf.d/ssl-params.conf

# Modern TLS only
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;

# Strong ciphers only
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';

# Session settings
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
ssl_session_tickets off;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;

# Security headers
add_header Strict-Transport-Security "max-age=63072000" always;
add_header X-Frame-Options DENY always;
add_header X-Content-Type-Options nosniff always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy strict-origin-when-cross-origin always;
add_header Content-Security-Policy "default-src 'self'" always;
```

### Certificate Auto-Renewal
```bash
# Test renewal
certbot renew --dry-run

# Add to crontab
0 0 1 * * certbot renew --quiet
```

---

## 6. Application Security

### Input Validation
All API endpoints use Zod schemas for validation:
```typescript
// Example validation
const loginSchema = z.object({
  phone: z.string().regex(/^\+?254\d{9}$/, 'Invalid phone number'),
});
```

### Rate Limiting
```typescript
// Express rate limiting
app.use(rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP',
}));
```

### SQL Injection Protection
- Using Prisma ORM with parameterized queries
- No raw SQL unless absolutely necessary

### XSS Protection
- Helmet.js for security headers
- Input sanitization on all user inputs
- Output encoding in templates

---

## 7. Authentication Security

### JWT Configuration
```typescript
// Use strong secrets
const JWT_SECRET = process.env.JWT_SECRET; // 64+ characters

// Short expiration for access tokens
const ACCESS_TOKEN_EXPIRY = '15m';

// Longer expiration for refresh tokens
const REFRESH_TOKEN_EXPIRY = '30d';

// Rotate refresh tokens on each use
// Invalidate old tokens immediately
```

### OTP Security
```typescript
// OTP Configuration
const OTP_LENGTH = 6;
const OTP_EXPIRY_MINUTES = 5;
const OTP_MAX_ATTEMPTS = 3;

// Rate limit OTP requests
const OTP_RATE_LIMIT = 3; // per 10 minutes per phone
```

---

## 8. WireGuard Security

### Key Management
```bash
# Generate keys securely
wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey

# Set strict permissions
chmod 600 /etc/wireguard/privatekey
chmod 644 /etc/wireguard/publickey
chown root:root /etc/wireguard/*
```

### Firewall Rules
```bash
# Allow only WireGuard traffic on specific port
ufw allow 51820/udp

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

### Peer Management
- Generate unique keys for each peer
- Assign specific IP addresses
- Monitor active connections
- Remove inactive peers regularly

---

## 9. Monitoring & Logging

### Security Logging
```typescript
// Log security events
logger.info('Security Event:', {
  event: 'login_attempt',
  ip: req.ip,
  phone: phone,
  success: true,
  timestamp: new Date().toISOString(),
});
```

### Log Rotation
```bash
# /etc/logrotate.d/maranet
/var/log/maranet/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data www-data
    postrotate
        systemctl reload maranet-api
    endscript
}
```

### Intrusion Detection
```bash
# Install and configure OSSEC or similar
apt install ossec-hids

# Monitor file integrity
# /etc/ossec/etc/ossec.conf
<syscheck>
  <directories>/etc,/usr/bin,/usr/sbin</directories>
  <directories>/opt/maranet</directories>
</syscheck>
```

---

## 10. Compliance & Auditing

### Data Protection
- [ ] Implement data encryption at rest
- [ ] Use TLS for all data in transit
- [ ] Implement data retention policies
- [ ] Enable audit logging for sensitive operations

### Access Control
- [ ] Implement role-based access control (RBAC)
- [ ] Use principle of least privilege
- [ ] Regular access reviews
- [ ] Multi-factor authentication for admin access

### Security Testing
- [ ] Regular vulnerability scans
- [ ] Penetration testing (quarterly)
- [ ] Dependency security scanning
- [ ] Code review for security issues

---

## 11. Incident Response

### Security Incident Procedures
1. **Detection**: Monitor alerts and logs
2. **Containment**: Isolate affected systems
3. **Investigation**: Analyze the incident
4. **Remediation**: Fix the vulnerability
5. **Recovery**: Restore normal operations
6. **Lessons Learned**: Document and improve

### Contact Information
- **Security Team:** [email/phone]
- **Incident Response:** [email/phone]
- **Data Protection Officer:** [email/phone]

---

## Security Checklist

### Before Deployment
- [ ] All default passwords changed
- [ ] SSL/TLS certificates configured
- [ ] Firewall rules implemented
- [ ] Rate limiting enabled
- [ ] Logging configured
- [ ] Backup procedures tested
- [ ] Security headers configured
- [ ] Input validation implemented

### Ongoing
- [ ] Regular security updates
- [ ] Vulnerability scans
- [ ] Access reviews
- [ ] Log reviews
- [ ] Penetration testing
- [ ] Security training

---

*This guide should be reviewed and updated regularly as new security threats emerge.*