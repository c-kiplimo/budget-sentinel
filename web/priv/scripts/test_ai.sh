#!/bin/sh
echo "Testing AI service connectivity..."
curl -s --max-time 10 http://ai_service.railway.internal:5000/api/v1/health && echo " - OK" || echo " - FAILED"

echo "Testing with short hostname..."
curl -s --max-time 10 http://ai-service.railway.internal:5000/api/v1/health && echo " - OK" || echo " - FAILED"

echo "Checking AI_SERVICE_URL env var:"
echo "AI_SERVICE_URL=$AI_SERVICE_URL"

echo "Testing configured URL..."
curl -s --max-time 10 $AI_SERVICE_URL/api/v1/health && echo " - OK" || echo " - FAILED"
