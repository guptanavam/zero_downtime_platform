#!/usr/bin/env python3
import concurrent.futures
import time
import urllib.request

TARGET_URL = "http://localhost/"
TOTAL_REQUESTS = 500
CONCURRENCY = 20  # Number of parallel worker threads firing simultaneously


def send_request(request_id):
    start = time.time()
    try:
        req = urllib.request.Request(TARGET_URL)
        with urllib.request.urlopen(req, timeout=5) as response:
            status = response.getcode()
            duration = time.time() - start
            return status, duration
    except Exception as e:
        return 500, time.time() - start


def main():
    print("==================================================")
    print(f"🔥 Starting Load Test against {TARGET_URL}")
    print(f"⚡ Total Requests : {TOTAL_REQUESTS}")
    print(f"👥 Concurrency    : {CONCURRENCY} parallel threads")
    print("==================================================")

    start_total = time.time()
    statuses = []
    durations = []

    with concurrent.futures.ThreadPoolExecutor(
        max_workers=CONCURRENCY
    ) as executor:
        futures = [
            executor.submit(send_request, i) for i in range(TOTAL_REQUESTS)
        ]
        for future in concurrent.futures.as_completed(futures):
            status, duration = future.result()
            statuses.append(status)
            durations.append(duration)

    total_time = time.time() - start_total
    success_count = statuses.count(200)
    error_count = len(statuses) - success_count
    rps = len(statuses) / total_time
    avg_latency = (sum(durations) / len(durations)) * 1000  # in milliseconds

    print("\n==================================================")
    print("📊 LOAD TEST RESULTS")
    print("==================================================")
    print(f"⏱️  Total Duration  : {total_time:.2f} seconds")
    print(f"🚀 Requests / Sec  : {rps:.2f} RPS")
    print(f"⚡ Avg Latency     : {avg_latency:.2f} ms")
    print(f"✅ Success (200 OK): {success_count}/{TOTAL_REQUESTS}")
    print(f"❌ Errors (5xx/Fail): {error_count}/{TOTAL_REQUESTS}")
    print("==================================================")


if __name__ == "__main__":
    main()