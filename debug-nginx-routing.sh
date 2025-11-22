#!/bin/bash
# Debug script for Nginx routing issues
# Run this on the EC2 instance to diagnose routing problems

echo "=========================================="
echo "Docker Container Status"
echo "=========================================="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=========================================="
echo "Nginx Configuration Files"
echo "=========================================="
ls -la /etc/nginx/conf.d/ 2>/dev/null || echo "No conf.d directory"
ls -la /etc/nginx/sites-enabled/ 2>/dev/null || echo "No sites-enabled directory"

echo ""
echo "=========================================="
echo "Generated Nginx Configs"
echo "=========================================="
if [ -d /etc/nginx/conf.d ]; then
    for conf in /etc/nginx/conf.d/*.conf; do
        if [ -f "$conf" ]; then
            echo "--- $conf ---"
            cat "$conf"
            echo ""
        fi
    done
fi

echo ""
echo "=========================================="
echo "Nginx Sites Enabled"
echo "=========================================="
if [ -d /etc/nginx/sites-enabled ]; then
    for site in /etc/nginx/sites-enabled/*; do
        if [ -f "$site" ]; then
            echo "--- $site ---"
            cat "$site"
            echo ""
        fi
    done
fi

echo ""
echo "=========================================="
echo "Nginx Status"
echo "=========================================="
systemctl status nginx --no-pager

echo ""
echo "=========================================="
echo "Test Nginx Config"
echo "=========================================="
nginx -t

echo ""
echo "=========================================="
echo "Nginx Auto-Config Service Status"
echo "=========================================="
systemctl status nginx-auto-config --no-pager || echo "Service not found"

echo ""
echo "=========================================="
echo "Container Labels (nginx.* labels)"
echo "=========================================="
for container in $(docker ps --format "{{.Names}}"); do
    echo "--- $container ---"
    docker inspect "$container" | jq -r '.[0].Config.Labels | to_entries[] | select(.key | startswith("nginx")) | "\(.key) = \(.value)"'
    echo ""
done

echo ""
echo "=========================================="
echo "Test Local Endpoints (Direct to Containers)"
echo "=========================================="
echo "Beneficiaries (port 8080):"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:8080/actuator/health || echo "Failed to connect"

echo "Payments (port 8081):"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:8081/actuator/health || echo "Failed to connect"

echo "Consumer (port 8082):"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:8082/actuator/health || echo "Failed to connect"

echo ""
echo "=========================================="
echo "Test Nginx Routing (via Nginx)"
echo "=========================================="
echo "Nginx health:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost/health

echo ""
echo "Beneficiaries via Nginx:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost/alok-sit-env/beneficiaries/actuator/health || echo "Failed"

echo "Payments via Nginx:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost/alok-sit-env/payments/actuator/health || echo "Failed"

echo "Consumer via Nginx:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost/alok-sit-env/consumer/actuator/health || echo "Failed"

echo ""
echo "=========================================="
echo "Docker Compose Environment Variables"
echo "=========================================="
if [ -f .env ]; then
    echo "Found .env file:"
    cat .env | grep -v PASSWORD || echo "No .env file"
else
    echo "No .env file found"
fi

echo ""
echo "=========================================="
echo "Nginx Error Logs (last 20 lines)"
echo "=========================================="
tail -20 /var/log/nginx/error.log 2>/dev/null || echo "No error log found"

echo ""
echo "=========================================="
echo "Nginx Access Logs (last 20 lines)"
echo "=========================================="
tail -20 /var/log/nginx/access.log 2>/dev/null || echo "No access log found"
