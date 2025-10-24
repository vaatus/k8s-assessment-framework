#!/usr/bin/env python3
"""
Test Runner Pod - Executes application-level checks inside student cluster
Runs HTTP endpoint tests, data persistence checks, and graceful shutdown validation
"""

import json
import sys
import requests
import time
from datetime import datetime


class TestRunner:
    def __init__(self, checks):
        self.checks = checks
        self.results = {}

    def run_all_checks(self):
        """
        Execute all checks defined in the test specification
        """
        for check in self.checks:
            check_id = check['check_id']
            check_type = check['check_type']

            print(f"Running check: {check_id} (type: {check_type})")

            try:
                if check_type == 'http_get':
                    result = self.http_get_check(check)
                elif check_type == 'http_post':
                    result = self.http_post_check(check)
                elif check_type == 'data_persistence':
                    result = self.data_persistence_check(check)
                elif check_type == 'graceful_shutdown':
                    result = self.graceful_shutdown_check(check)
                else:
                    print(f"Unknown check type: {check_type}")
                    result = {
                        'passed': False,
                        'message': f'Unknown check type: {check_type}'
                    }

                self.results[check_id] = result

            except Exception as e:
                print(f"Error running check {check_id}: {e}")
                self.results[check_id] = {
                    'passed': False,
                    'message': str(e)
                }

        return self.results

    def http_get_check(self, check):
        """
        Perform HTTP GET request and validate response
        """
        service = check.get('service')
        port = check.get('port', 80)
        path = check.get('path', '/')
        namespace = check.get('namespace', 'default')
        target_pod = check.get('target_pod')
        expected_status = check.get('expected_status', 200)
        expected_body_contains = check.get('expected_body_contains')
        expected_json_fields = check.get('expected_json_fields', [])
        timeout = check.get('timeout', 30)

        # Build URL (cluster-internal)
        if target_pod:
            url = f'http://{target_pod}.{service}.{namespace}.svc.cluster.local:{port}{path}'
        else:
            url = f'http://{service}.{namespace}.svc.cluster.local:{port}{path}'

        print(f"  GET {url}")

        try:
            response = requests.get(url, timeout=timeout)

            # Check status code
            status_ok = (response.status_code == expected_status)

            # Check body contains expected string
            body_ok = True
            if expected_body_contains:
                body_ok = expected_body_contains in response.text

            # Check JSON fields
            json_ok = True
            if expected_json_fields:
                try:
                    data = response.json()
                    json_ok = all(field in data for field in expected_json_fields)
                except:
                    json_ok = False

            passed = status_ok and body_ok and json_ok

            return {
                'passed': passed,
                'status_code': response.status_code,
                'status_ok': status_ok,
                'body_ok': body_ok,
                'json_ok': json_ok,
                'message': f'Status: {response.status_code}, Body check: {body_ok}, JSON check: {json_ok}'
            }

        except requests.exceptions.Timeout:
            return {
                'passed': False,
                'message': f'Request timeout after {timeout}s'
            }
        except requests.exceptions.ConnectionError as e:
            return {
                'passed': False,
                'message': f'Connection error: {str(e)}'
            }
        except Exception as e:
            return {
                'passed': False,
                'message': f'Error: {str(e)}'
            }

    def http_post_check(self, check):
        """
        Perform HTTP POST request and validate response
        """
        service = check.get('service')
        port = check.get('port', 80)
        path = check.get('path', '/')
        namespace = check.get('namespace', 'default')
        target_pod = check.get('target_pod')
        body = check.get('body', '')
        expected_status = check.get('expected_status', 200)
        timeout = check.get('timeout', 30)

        # Build URL
        if target_pod:
            url = f'http://{target_pod}.{service}.{namespace}.svc.cluster.local:{port}{path}'
        else:
            url = f'http://{service}.{namespace}.svc.cluster.local:{port}{path}'

        print(f"  POST {url}")

        try:
            response = requests.post(url, data=body, timeout=timeout)

            status_ok = (response.status_code == expected_status)

            return {
                'passed': status_ok,
                'status_code': response.status_code,
                'message': f'Status: {response.status_code}'
            }

        except requests.exceptions.Timeout:
            return {
                'passed': False,
                'message': f'Request timeout after {timeout}s'
            }
        except Exception as e:
            return {
                'passed': False,
                'message': f'Error: {str(e)}'
            }

    def data_persistence_check(self, check):
        """
        Check data persistence by storing, restarting pod, and retrieving
        """
        steps = check.get('validation_steps', [])
        namespace = check.get('namespace', 'default')

        print(f"  Running data persistence test with {len(steps)} steps")

        # This is a complex check that would need kubectl access
        # For now, return a placeholder
        return {
            'passed': False,
            'message': 'Data persistence check requires kubectl access (not implemented yet)'
        }

    def graceful_shutdown_check(self, check):
        """
        Check graceful shutdown behavior
        """
        steps = check.get('validation_steps', [])

        print(f"  Running graceful shutdown test with {len(steps)} steps")

        # This is a complex check that would need kubectl access
        return {
            'passed': False,
            'message': 'Graceful shutdown check requires kubectl access (not implemented yet)'
        }


def main():
    """
    Main entry point - reads checks from stdin and outputs results to stdout
    """
    print("Test Runner Starting...")
    print(f"Time: {datetime.utcnow().isoformat()}")

    try:
        # Read checks from stdin (passed by Lambda)
        input_data = sys.stdin.read()
        checks_spec = json.loads(input_data)

        checks = checks_spec.get('checks', [])
        print(f"Loaded {len(checks)} checks")

        # Run all checks
        runner = TestRunner(checks)
        results = runner.run_all_checks()

        # Output results as JSON to stdout
        output = {
            'success': True,
            'timestamp': datetime.utcnow().isoformat(),
            'results': results
        }

        print("\n=== TEST RESULTS ===")
        print(json.dumps(output, indent=2))

    except Exception as e:
        print(f"Fatal error: {e}", file=sys.stderr)
        output = {
            'success': False,
            'error': str(e)
        }
        print(json.dumps(output, indent=2))
        sys.exit(1)


if __name__ == '__main__':
    main()
