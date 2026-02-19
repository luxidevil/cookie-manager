import requests
import json
import sys
from datetime import datetime

class CookieManagerAPITester:
    def __init__(self, base_url="https://cookie-paste-verify.preview.emergentagent.com/api"):
        self.base_url = base_url
        self.token = None
        self.tests_run = 0
        self.tests_passed = 0
        self.test_results = []

    def log_result(self, name, success, details=""):
        """Log test result"""
        self.tests_run += 1
        if success:
            self.tests_passed += 1
        
        result = {
            "test": name,
            "status": "PASS" if success else "FAIL",
            "details": details
        }
        self.test_results.append(result)
        
        status_icon = "✅" if success else "❌"
        print(f"{status_icon} {name}: {details}")

    def run_test(self, name, method, endpoint, expected_status, data=None, headers=None):
        """Run a single API test"""
        url = f"{self.base_url}/{endpoint}"
        test_headers = {'Content-Type': 'application/json'}
        
        if self.token:
            test_headers['Authorization'] = f'Bearer {self.token}'
        
        if headers:
            test_headers.update(headers)

        try:
            if method == 'GET':
                response = requests.get(url, headers=test_headers, timeout=10)
            elif method == 'POST':
                response = requests.post(url, json=data, headers=test_headers, timeout=10)
            elif method == 'PATCH':
                response = requests.patch(url, json=data, headers=test_headers, timeout=10)
            elif method == 'DELETE':
                response = requests.delete(url, headers=test_headers, timeout=10)

            success = response.status_code == expected_status
            
            if success:
                self.log_result(name, True, f"Status: {response.status_code}")
                try:
                    return True, response.json()
                except:
                    return True, response.text
            else:
                error_msg = f"Expected {expected_status}, got {response.status_code}"
                try:
                    error_detail = response.json().get('detail', '')
                    if error_detail:
                        error_msg += f" - {error_detail}"
                except:
                    pass
                
                self.log_result(name, False, error_msg)
                return False, {}

        except requests.exceptions.RequestException as e:
            self.log_result(name, False, f"Request failed: {str(e)}")
            return False, {}
        except Exception as e:
            self.log_result(name, False, f"Error: {str(e)}")
            return False, {}

    def test_health_check(self):
        """Test health endpoint"""
        return self.run_test("Health Check", "GET", "health", 200)

    def test_login_valid_credentials(self):
        """Test login with valid credentials"""
        success, response = self.run_test(
            "Login - Valid Credentials",
            "POST",
            "auth/login",
            200,
            data={"username": "seko", "password": "SEKO1234"}
        )
        
        if success and 'token' in response:
            self.token = response['token']
            self.log_result("Token Storage", True, "JWT token saved for subsequent requests")
            return True
        else:
            self.log_result("Token Storage", False, "No token received")
            return False

    def test_login_invalid_credentials(self):
        """Test login with invalid credentials"""
        return self.run_test(
            "Login - Invalid Credentials",
            "POST", 
            "auth/login",
            401,
            data={"username": "wrong", "password": "wrong"}
        )

    def test_auth_verify(self):
        """Test auth verification with token"""
        return self.run_test("Auth Verification", "GET", "auth/verify", 200)

    def test_validate_valid_json(self):
        """Test cookie validation with valid JSON"""
        valid_json = '[{"name": "session", "value": "abc123", "domain": ".example.com"}]'
        success, response = self.run_test(
            "Cookie Validation - Valid JSON",
            "POST",
            "cookies/validate",
            200,
            data={"content": valid_json}
        )
        
        if success and response.get('valid'):
            self.log_result("JSON Validation Result", True, "JSON marked as valid")
            return True, response
        else:
            self.log_result("JSON Validation Result", False, "Valid JSON not recognized")
            return False, response

    def test_validate_invalid_json(self):
        """Test cookie validation with invalid JSON"""
        invalid_json = '{"name": "session", "value": "abc123"'  # Missing closing brace
        success, response = self.run_test(
            "Cookie Validation - Invalid JSON",
            "POST",
            "cookies/validate",
            200,
            data={"content": invalid_json}
        )
        
        if success and not response.get('valid'):
            self.log_result("Invalid JSON Detection", True, "Invalid JSON correctly detected")
            return True
        else:
            self.log_result("Invalid JSON Detection", False, "Invalid JSON not detected")
            return False

    def test_create_cookie(self):
        """Test creating a cookie"""
        valid_json = '[{"name": "test_cookie", "value": "test_value", "domain": ".test.com"}]'
        success, response = self.run_test(
            "Create Cookie",
            "POST",
            "cookies",
            200,
            data={"content": valid_json}
        )
        
        if success and 'id' in response:
            self.cookie_id = response['id']
            self.log_result("Cookie Creation", True, f"Cookie created with ID: {self.cookie_id}")
            return True, response
        else:
            self.log_result("Cookie Creation", False, "No cookie ID returned")
            return False, response

    def test_get_all_cookies(self):
        """Test getting all cookies"""
        return self.run_test("Get All Cookies", "GET", "cookies", 200)

    def test_get_specific_cookie(self, cookie_id):
        """Test getting a specific cookie"""
        return self.run_test(
            "Get Specific Cookie",
            "GET",
            f"cookies/{cookie_id}",
            200
        )

    def test_update_cookie_sold_status(self, cookie_id):
        """Test updating cookie sold status"""
        return self.run_test(
            "Update Cookie - Sold Status",
            "PATCH",
            f"cookies/{cookie_id}",
            200,
            data={"sold": True}
        )

    def test_update_cookie_expired_status(self, cookie_id):
        """Test updating cookie expired status"""
        return self.run_test(
            "Update Cookie - Expired Status", 
            "PATCH",
            f"cookies/{cookie_id}",
            200,
            data={"expired": True}
        )

    def test_update_cookie_link_generated(self, cookie_id):
        """Test updating cookie link_generated status"""
        return self.run_test(
            "Update Cookie - Link Generated",
            "PATCH", 
            f"cookies/{cookie_id}",
            200,
            data={"link_generated": True}
        )

    def test_unauthorized_access(self):
        """Test accessing protected endpoints without token"""
        old_token = self.token
        self.token = None
        
        success, _ = self.run_test(
            "Unauthorized Access - Get Cookies",
            "GET",
            "cookies",
            401
        )
        
        self.token = old_token
        return success

def main():
    print("🍪 Cookie Manager API Testing")
    print("=" * 50)
    
    tester = CookieManagerAPITester()
    cookie_id = None

    # Test sequence
    print("\n📡 Testing API Connectivity...")
    tester.test_health_check()

    print("\n🔐 Testing Authentication...")
    if not tester.test_login_valid_credentials():
        print("❌ Cannot proceed without valid login")
        return 1
    
    tester.test_login_invalid_credentials()
    tester.test_auth_verify()
    tester.test_unauthorized_access()

    print("\n✅ Testing Cookie Validation...")
    valid_result = tester.test_validate_valid_json()
    tester.test_validate_invalid_json()

    print("\n🍪 Testing Cookie CRUD Operations...")
    create_success, create_response = tester.test_create_cookie()
    if create_success:
        cookie_id = create_response.get('id')
        
        tester.test_get_all_cookies()
        tester.test_get_specific_cookie(cookie_id)
        
        # Test status updates
        tester.test_update_cookie_sold_status(cookie_id)
        tester.test_update_cookie_expired_status(cookie_id)
        tester.test_update_cookie_link_generated(cookie_id)

    # Print final results
    print("\n" + "=" * 50)
    print(f"📊 Test Results: {tester.tests_passed}/{tester.tests_run} passed")
    
    if tester.tests_passed == tester.tests_run:
        print("🎉 All tests passed!")
        return 0
    else:
        print("⚠️ Some tests failed!")
        return 1

if __name__ == "__main__":
    sys.exit(main())