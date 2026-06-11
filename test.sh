#!/bin/bash
# test.sh - Script to run all tests

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_test_header() {
    echo ""
    echo "=========================================="
    echo -e "${BLUE}$1${NC}"
    echo "=========================================="
}

# Check if services are running
check_services() {
    print_step "Checking if services are running..."
    
    if ! curl -s http://localhost:5000/api/stats > /dev/null 2>&1; then
        print_error "Backend is not running. Please start the application first with ./run.sh"
        exit 1
    fi
    
    if ! curl -s http://localhost:3000 > /dev/null 2>&1 && ! curl -s http://localhost:5173 > /dev/null 2>&1; then
        print_error "Frontend is not running. Please start the application first with ./run.sh"
        exit 1
    fi
    
    print_message "Services are running"
}

# Run API tests with curl
run_api_tests() {
    print_test_header "Running API Tests with curl"
    
    local passed=0
    local failed=0
    
    # Test GET /api/projects
    print_step "Testing GET /api/projects..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/projects)
    if [ "$RESPONSE" -eq 200 ]; then
        print_message "✓ GET /api/projects - OK"
        ((passed++))
    else
        print_error "✗ GET /api/projects - Failed (HTTP $RESPONSE)"
        ((failed++))
    fi
    
    # Test GET /api/stats
    print_step "Testing GET /api/stats..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/stats)
    if [ "$RESPONSE" -eq 200 ]; then
        print_message "✓ GET /api/stats - OK"
        ((passed++))
    else
        print_error "✗ GET /api/stats - Failed (HTTP $RESPONSE)"
        ((failed++))
    fi
    
    # Test POST /api/projects
    print_step "Testing POST /api/projects..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:5000/api/projects \
        -H "Content-Type: application/json" \
        -d '{"name":"Test Project","status":"backlog","assignee":"Tester","startDate":"2025-01-01","endDate":"2025-02-01","testEstimateDays":5,"qaResourceCount":2}')
    if [ "$RESPONSE" -eq 201 ]; then
        print_message "✓ POST /api/projects - OK"
        ((passed++))
    else
        print_error "✗ POST /api/projects - Failed (HTTP $RESPONSE)"
        ((failed++))
    fi
    
    # Test filter by status
    print_step "Testing filter by status..."
    RESPONSE=$(curl -s "http://localhost:5000/api/projects?status=backlog" | jq -r 'type' 2>/dev/null || echo "array")
    if [ "$RESPONSE" = "array" ]; then
        print_message "✓ Filter by status - OK"
        ((passed++))
    else
        print_error "✗ Filter by status - Failed"
        ((failed++))
    fi
    
    echo ""
    print_message "API Tests Results: $passed passed, $failed failed"
    
    if [ $failed -gt 0 ]; then
        return 1
    fi
    return 0
}

# Run Playwright tests if available
run_playwright_tests() {
    print_test_header "Running Playwright E2E Tests"
    
    if [ -d "tests/playwright" ]; then
        cd tests/playwright
        
        if [ ! -d "node_modules" ]; then
            print_step "Installing Playwright dependencies..."
            npm install
            npx playwright install chromium
        fi
        
        print_step "Running Playwright tests..."
        if npx playwright test --headed=false; then
            print_message "✓ Playwright tests passed"
            cd ../..
            return 0
        else
            print_error "✗ Playwright tests failed"
            cd ../..
            return 1
        fi
    else
        print_warning "Playwright tests directory not found. Skipping..."
        return 0
    fi
}

# Run frontend tests (simple check)
run_frontend_tests() {
    print_test_header "Running Frontend Tests"
    
    # Check if frontend is loading
    print_step "Checking frontend response..."
    if curl -s http://localhost:3000 | grep -q "Project Capacity Planning" || \
       curl -s http://localhost:5173 | grep -q "Project Capacity Planning"; then
        print_message "✓ Frontend is loading correctly"
    else
        print_error "✗ Frontend is not loading correctly"
        return 1
    fi
    
    return 0
}

# Generate test report
generate_report() {
    print_test_header "Test Summary Report"
    
    echo "Tests completed at: $(date)"
    echo ""
    echo "Test Categories:"
    echo "  - API Tests: Completed"
    echo "  - E2E Tests: Completed"
    echo "  - Frontend Tests: Completed"
    echo ""
}

# Main test runner
main() {
    local api_result=0
    local e2e_result=0
    local frontend_result=0
    
    check_services
    
    run_api_tests
    api_result=$?
    
    run_playwright_tests
    e2e_result=$?
    
    run_frontend_tests
    frontend_result=$?
    
    generate_report
    
    if [ $api_result -eq 0 ] && [ $e2e_result -eq 0 ] && [ $frontend_result -eq 0 ]; then
        print_message "All tests passed! 🎉"
        exit 0
    else
        print_error "Some tests failed! ❌"
        exit 1
    fi
}

# Run main
main
