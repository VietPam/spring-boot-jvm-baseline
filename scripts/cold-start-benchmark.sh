#!/usr/bin/env bash
# Do cold start benchmark cho baseline nay - script duoc thiet ke de dung lai
# y het (khong sua doi) o repo spring-boot-jvm-baseline, chi khac ten image tu
# dong suy ra tu ten thu muc, de dam bao 2 ben do cung 1 phuong phap, so sanh
# duoc voi nhau. Xem docs/benchmark.md de biet dinh nghia tung metric.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_NAME="$(basename "$REPO_DIR")"
IMAGE_NAME="${IMAGE_NAME:-${REPO_NAME}:local}"
CONTAINER_NAME="${CONTAINER_NAME:-${REPO_NAME}-bench}"
PORT="${PORT:-18080}"
URL="http://localhost:${PORT}/"
TRIALS="${TRIALS:-10}"
READY_TIMEOUT_S="${READY_TIMEOUT_S:-30}"
RESULTS_DIR="${REPO_DIR}/scripts/results"
RAW_CSV="${RESULTS_DIR}/${REPO_NAME}-$(date +%Y%m%d-%H%M%S).csv"

mkdir -p "$RESULTS_DIR"

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

now_ns() { date +%s%N; }

echo "== Repo: ${REPO_NAME} =="
echo "== Image: ${IMAGE_NAME} =="

echo
echo "-- [0/2] Build image (docker build --no-cache), do thoi gian build --"
BUILD_START_NS=$(now_ns)
docker build --no-cache -t "$IMAGE_NAME" "$REPO_DIR" >"${RESULTS_DIR}/${REPO_NAME}-build.log" 2>&1
BUILD_END_NS=$(now_ns)
BUILD_S=$(awk -v a="$BUILD_START_NS" -v b="$BUILD_END_NS" 'BEGIN{printf "%.2f", (b-a)/1000000000}')
echo "Build xong trong ${BUILD_S}s (log: ${RESULTS_DIR}/${REPO_NAME}-build.log)"

# CONTENT SIZE (.Size / docker save): kich thuoc nen, deduplicated - dung khi push/pull registry
# (Render pull image cung theo con so nay). DISK USAGE (docker images): dung luong that tren dia
# sau khi unpack layer (bao gom ca base layer da co san local) - lon hon vi khong nen + co the trung
# lap voi image khac dang co san. Ghi ca 2 de tranh nham lan khi so sanh giua 2 repo.
IMAGE_SIZE_BYTES=$(docker image inspect -f '{{.Size}}' "$IMAGE_NAME")
IMAGE_SIZE_MB=$(awk -v b="$IMAGE_SIZE_BYTES" 'BEGIN{printf "%.1f", b/1000/1000}')
IMAGE_DISK_USAGE=$(docker images "$IMAGE_NAME" --format '{{.Size}}' | head -1)
echo "Image content size (nen, ~kich thuoc push/pull registry): ${IMAGE_SIZE_MB} MB"
echo "Image disk usage (da giai nen tren dia): ${IMAGE_DISK_USAGE}"

echo
echo "-- [1/2] ${TRIALS} lan chay: do 'cold start' (docker run -> HTTP 200 dau tien) --"
echo "trial,cold_start_ms,self_reported_start_s,mem_mib" > "$RAW_CSV"

for i in $(seq 1 "$TRIALS"); do
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

  START_NS=$(now_ns)
  docker run -d --name "$CONTAINER_NAME" -p "${PORT}:8080" "$IMAGE_NAME" >/dev/null

  READY=0
  DEADLINE=$(( $(date +%s) + READY_TIMEOUT_S ))
  while [ "$(date +%s)" -lt "$DEADLINE" ]; do
    CODE=$(curl -s -o /dev/null -w '%{http_code}' "$URL" 2>/dev/null || true)
    if [ "$CODE" = "200" ]; then
      READY=1
      break
    fi
    sleep 0.02
  done
  END_NS=$(now_ns)

  if [ "$READY" -ne 1 ]; then
    echo "  [trial ${i}] KHONG san sang trong ${READY_TIMEOUT_S}s - bo qua trial nay"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    continue
  fi

  COLD_START_MS=$(awk -v a="$START_NS" -v b="$END_NS" 'BEGIN{printf "%.1f", (b-a)/1000000}')

  # Thoi gian app tu bao cao (log Spring Boot "Started ... in X seconds"), tham khao rieng,
  # KHONG bao gom overhead cua Docker/container runtime.
  SELF_REPORTED_S=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -oE 'Started [A-Za-z0-9]+ in [0-9.]+ seconds' | grep -oE '[0-9.]+' | head -1)
  SELF_REPORTED_S="${SELF_REPORTED_S:-NA}"

  MEM_MIB=$(docker stats --no-stream --format '{{.MemUsage}}' "$CONTAINER_NAME" 2>/dev/null | awk -F'/' '{print $1}' | grep -oE '[0-9.]+' | head -1)
  MEM_MIB="${MEM_MIB:-NA}"

  echo "  [trial ${i}] cold_start=${COLD_START_MS}ms  self_reported=${SELF_REPORTED_S}s  mem=${MEM_MIB}MiB"
  echo "${i},${COLD_START_MS},${SELF_REPORTED_S},${MEM_MIB}" >> "$RAW_CSV"

  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
done

echo
echo "-- [2/2] Tong hop --"
N=$(($(wc -l < "$RAW_CSV") - 1))
if [ "$N" -le 0 ]; then
  echo "Khong co trial nao thanh cong"
  exit 1
fi

CS_SORTED=$(tail -n +2 "$RAW_CSV" | cut -d',' -f2 | sort -n)
MIN_CS=$(echo "$CS_SORTED" | head -1)
MAX_CS=$(echo "$CS_SORTED" | tail -1)
MEAN_CS=$(echo "$CS_SORTED" | awk '{s+=$1} END{printf "%.1f", s/NR}')
MEDIAN_CS=$(echo "$CS_SORTED" | awk -v n="$N" '{a[NR]=$1} END{if(n%2==1) printf "%.1f", a[(n+1)/2]; else printf "%.1f", (a[n/2]+a[n/2+1])/2}')

SR_SORTED=$(tail -n +2 "$RAW_CSV" | cut -d',' -f3 | grep -v '^NA$' | sort -n || true)
if [ -n "$SR_SORTED" ]; then
  MEAN_SR=$(echo "$SR_SORTED" | awk '{s+=$1; c++} END{printf "%.3f", s/c}')
else
  MEAN_SR="NA"
fi

MEM_SORTED=$(tail -n +2 "$RAW_CSV" | cut -d',' -f4 | grep -v '^NA$' | sort -n || true)
if [ -n "$MEM_SORTED" ]; then
  MEAN_MEM=$(echo "$MEM_SORTED" | awk '{s+=$1; c++} END{printf "%.1f", s/c}')
else
  MEAN_MEM="NA"
fi

echo "Image: ${IMAGE_NAME}"
echo "Image content size (nen, push/pull): ${IMAGE_SIZE_MB} MB"
echo "Image disk usage (da giai nen): ${IMAGE_DISK_USAGE}"
echo "Build time (no cache): ${BUILD_S}s"
echo "Cold start (docker run -> HTTP 200 dau tien), n=${N} trial:"
echo "  min=${MIN_CS}ms  median=${MEDIAN_CS}ms  mean=${MEAN_CS}ms  max=${MAX_CS}ms"
echo "Self-reported Spring Boot startup (trung binh): ${MEAN_SR}s"
echo "Memory RSS luc idle (trung binh): ${MEAN_MEM} MiB"

echo
echo "Raw CSV: ${RAW_CSV}"
