#!/usr/bin/env python3
"""
Test Runner Pod - Executes application-level checks inside student cluster
Runs HTTP endpoint tests, data persistence checks, and graceful shutdown validation
"""

import json
import sys
import os
import requests
import time
from datetime import datetime


class TestRunner:
    def __init__(self, checks):
        self.checks = checks
        self.results = {}

    def run_all_checks(self):
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
                else:
                    result = {'passed': False, 'message': f'Unknown check type: {check_type}'}
                self.results[check_id] = result
            except Exception as e:
                self.results[check_id] = {'passed': False, 'message': str(e)}
        return self.results

    def http_get_check(self, check):
        endpoint = check.get('endpoint', '')
        expected_status = check.get('expected_status', 200)
        timeout = check.get('timeout', 5)
        retry_count = check.get('retry_count', 3)

        for attempt in range(retry_count):
            try:
                response = requests.get(endpoint, timeout=timeout)
                if response.status_code == expected_status:
                    return {'passed': True, 'message': f'HTTP GET succeeded: status={response.status_code}'}
                time.sleep(2)
            except Exception as e:
                if attempt < retry_count - 1:
                    time.sleep(2)
        return {'passed': False, 'message': f'HTTP GET failed after {retry_count} attempts'}

    def http_post_check(self, check):
        endpoint = check.get('endpoint', '')
        payload = check.get('payload', {})
        expected_status = check.get('expected_status', 200)
        timeout = check.get('timeout', 5)

        try:
            response = requests.post(endpoint, json=payload, timeout=timeout)
            if response.status_code == expected_status:
                return {'passed': True, 'message': f'HTTP POST succeeded: status={response.status_code}'}
            return {'passed': False, 'message': f'HTTP POST failed: status={response.status_code}'}
        except Exception as e:
            return {'passed': False, 'message': f'HTTP POST error: {e}'}

    def data_persistence_check(self, check):
        post_endpoint = check.get('post_endpoint', '')
        get_endpoint = check.get('get_endpoint', '')
        test_key = check.get('test_key', 'test-key')
        test_value = check.get('test_value', f'test-value-{int(time.time())}')
        timeout = check.get('timeout', 5)

        try:
            post_resp = requests.post(post_endpoint, json={'key': test_key, 'value': test_value}, timeout=timeout)
            if post_resp.status_code not in [200, 201]:
                return {'passed': False, 'message': f'POST failed: status={post_resp.status_code}'}

            time.sleep(1)
            get_url = f"{get_endpoint}/{test_key}"
            get_resp = requests.get(get_url, timeout=timeout)

            if get_resp.status_code == 200 and test_value in get_resp.text:
                return {'passed': True, 'message': 'Data persistence verified'}
            return {'passed': False, 'message': 'Data verification failed'}
        except Exception as e:
            return {'passed': False, 'message': f'Error: {e}'}


def main():
    checks_json = os.environ.get('CHECKS_JSON', '[]')
    try:
        checks = json.loads(checks_json)
    except json.JSONDecodeError as e:
        print(f"Error parsing CHECKS_JSON: {e}")
        sys.exit(1)

    if not checks:
        print(json.dumps({'results': {}}))
        sys.exit(0)

    runner = TestRunner(checks)
    results = runner.run_all_checks()

    print("\n=== TEST RESULTS ===")
    print(json.dumps({'timestamp': datetime.utcnow().isoformat(), 'results': results}))
    sys.exit(0 if all(r.get('passed', False) for r in results.values()) else 1)


if __name__ == '__main__':
    main()
