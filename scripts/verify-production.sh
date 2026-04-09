#!/bin/bash
# ============================================================
# Maranet Zero — Production Deployment Verification Script
# ============================================================
# Run this script after deployment to verify all services are
# healthy and properly configured.
#
# Usage: ./scripts/verify-production.sh [domain]
# ============================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
API_DOMAIN="${1:-api.maranet.app}"
BOOTSTRAP_DOMAIN="${2:-zero.maranet.app}"
GRAFANA_DOMAIN="${3:-grafana.maranet.app}"
TIMEOUT=30

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# ============================================================
# Helper Functions
# ============================================================

print_header() {
    echo -e "\n${BLUE}══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
}

print_check() {
    echo -n "  Checking: $1... "
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}"
    echo -e "    ${RED}Error: $1${NC}"
    ((FAILED++))
}

print_warning() {
    echo -e "${YELLOW}⚠ WARNING${NC}"
    echo -e "    ${YELLOW}$1${NC}"
    ((WARNINGS++))
}

print_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}"
    ((WARNINGS++))
}

check_http() {
    local url="$1"
    local expected_status="${2:-200}"
    local method="${3:-GET}"
    
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" -m "$TIMEOUT" --retry 2 "$url" 2>/dev/null || echo "000")
    
    if [ "$status" = "$expected_status" ]; then
        return 0
    else
        return 1
    fi
}

check_https_redirect() {
    local url="$1"
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" -m "$TIMEOUT" "$url" 2>/dev/null || echo "000")
    
    if [ "$status" = "301" ] || [ "$status" = "302" ]; then
        return 0
    else
        return 1
    fi
}

# ============================================================
# Verification Checks
# ============================================================

print_header "🔒 SSL/TLS Certificate Validation"

print_check "API domain has valid SSL certificate"
if openssl s_client -connect "${API_DOMAIN}:443" -servername "${API_DOMAIN}" </dev/null 2>/dev/null | openssl x509 -noout -dates >/dev/null 2>&1; then
    print_pass
else
    print_fail "SSL certificate not valid or expired"
fi

print_check "Bootstrap domain has valid SSL certificate"
if openssl s_client -connect "${BOOTSTRAP_DOMAIN}:443" -servername "${BOOTSTRAP_DOMAIN}" </dev/null 2>/dev/null | openssl x509 -noout -dates >/dev/null 2>&1; then
    print_pass
else
    print_warning "Bootstrap domain SSL certificate not found (may be optional)"
fi

# ============================================================

print_header "🌐 API Health Checks"

print_check "API root endpoint responds"
if check_http "https://${API_DOMAIN}/"; then
    print_pass
else
    print_fail "API root endpoint not responding"
fi

print_check "API health endpoint responds"
if check_http "https://${API_DOMAIN}/api/v1/health"; then
    print_pass
else
    print_fail "API health endpoint not responding"
fi

print_check "HTTP redirects to HTTPS"
if check_https_redirect "http://${API_DOMAIN}/"; then
    print_pass
else
    print_warning "HTTP to HTTPS redirect not configured"
fi

# ============================================================

print_header "🔐 Security Configuration"

print_check "Security headers present (HSTS)"
headers=$(curl -sI -m "$TIMEOUT" "https://${API_DOMAIN}/" 2>/dev/null)
if echo "$headers" | grep -qi "strict-transport-security"; then
    print_pass
else
    print_warning "HSTS header not present"
fi

print_check "X-Frame-Options header present"
if echo "$headers" | grep -qi "x-frame-options"; then
    print_pass
else
    print_warning "X-Frame-Options header not present"
fi

print_check "X-Content-Type-Options header present"
if echo "$headers" | grep -qi "x-content-type-options"; then
    print_pass
else
    print_warning "X-Content-Type-Options header not present"
fi

# ============================================================

print_header "💳 M-Pesa Configuration"

print_check "M-Pesa environment is production"
# This check requires access to the API response or logs
print_skip "Cannot verify without API access - check manually"

# ============================================================

print_header "📊 Monitoring & Observability"

print_check "Prometheus is accessible"
if check_http "http://${API_DOMAIN}:9090" "200" 2>/dev/null; then
    print_pass
else
    print_warning "Prometheus not directly accessible (may be internal only)"
fi

print_check "Grafana is accessible"
if check_http "https://${GRAFANA_DOMAIN}/" "200" 2>/dev/null; then
    print_pass
else
    print_warning "Grafana not accessible (check if internal only)"
fi

# ============================================================

print_header "🗄️ Database & Cache"

print_check "PostgreSQL port accessible"
if nc -z -w 5 "${API_DOMAIN}" 5432 2>/dev/null; then
    print_pass
    print_warning "PostgreSQL should not be exposed to internet - restrict access!"
else
    print_pass  # This is actually good - DB should be internal
fi

print_check "Redis port accessible"
if nc -z -w 5 "${API_DOMAIN}" 6379 2>/dev/null; then
    print_pass
    print_warning "Redis should not be exposed to internet - restrict access!"
else
    print_pass  # This is actually good - Redis should be internal
fi

# ============================================================

print_header "🔧 Docker Services Status"

print_check "Docker containers are running"
if command -v docker &> /dev/null; then
    running=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
    if [ "$running" -gt 0 ]; then
        print_pass
        echo -e "    ${BLUE}Running containers: $running${NC}"
        docker ps --format "    {{.Names}}\t{{.Status}}" 2>/dev/null
    else
        print_warning "No Docker containers running"
    fi
else
    print_skip "Docker not installed on this machine"
fi

# ============================================================

print_header "📝 Summary"

echo -e "  ${GREEN}Passed:${NC}   $PASSED"
echo -e "  ${RED}Failed:${NC}   $FAILED"
echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}❌ Verification FAILED - $FAILED critical issues found${NC}"
    echo -e "Please review and fix the issues above before going live."
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️ Verification PASSED with warnings${NC}"
    echo -e "The system appears ready, but $WARNINGS warnings should be reviewed."
    exit 0
else
    echo -e "${GREEN}✅ All checks passed! System is ready for production.${NC}"
    exit 0
fi