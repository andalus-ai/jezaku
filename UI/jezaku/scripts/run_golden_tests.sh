#!/bin/bash

# ============================================================
# SCRIPT: Menjalankan Golden Tests - jezaku UI
# ============================================================
# 
# Penggunaan:
#   ./scripts/run_golden_tests.sh [option]
#
# Options:
#   all          - Jalankan semua golden tests (default)
#   auth         - Test layar autentikasi saja
#   main         - Test layar utama saja
#   chat         - Test layar chat saja
#   components   - Test component gallery chat saja
#   admin        - Test admin & feedback saja
#   security     - Test security screens saja
#   additional   - Test layar tambahan saja
#   update       - Update semua golden baseline
#   verify       - Verifikasi tanpa update (check only)
#   help         - Tampilkan bantuan
#
# Contoh:
#   ./scripts/run_golden_tests.sh all
#   ./scripts/run_golden_tests.sh auth
#   ./scripts/run_golden_tests.sh components
#   ./scripts/run_golden_tests.sh update
#   ./scripts/run_golden_tests.sh verify
#
# ============================================================

set -e

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directory script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$PROJECT_DIR/test"

# Fungsi bantuan
show_help() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   📸 Golden Test Runner - jezaku UI                   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Penggunaan:${NC}"
    echo "  ./scripts/run_golden_tests.sh [option]"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  all          Jalankan semua golden tests (default)"
    echo "  auth         Test layar autentikasi (login, register, dll)"
    echo "  main         Test layar utama (beranda, menu, profil)"
    echo "  chat         Test layar chat (daftar chat, ruang chat, call)"
    echo "  components   Test gallery komponen chat reusable"
    echo "  admin        Test admin dashboard & feedback"
    echo "  security     Test pattern lock screens"
    echo "  additional   Test viewer, settings, onboarding"
    echo "  update       Update semua golden baseline screenshots"
    echo "  verify       Verifikasi tanpa update (check only)"
    echo "  help         Tampilkan bantuan ini"
    echo ""
    echo -e "${YELLOW}Contoh:${NC}"
    echo "  ./scripts/run_golden_tests.sh all          # Semua tests"
    echo "  ./scripts/run_golden_tests.sh auth         # Auth tests saja"
    echo "  ./scripts/run_golden_tests.sh components   # Gallery komponen chat"
    echo "  ./scripts/run_golden_tests.sh update       # Update baseline"
    echo "  ./scripts/run_golden_tests.sh verify       # Verify changes"
    echo ""
}

# Fungsi jalankan test
run_test() {
    local test_file=$1
    local description=$2
    local update_flag=${3:-}
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}📱 Running: ${description}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ -f "$TEST_DIR/$test_file" ]; then
        cd "$PROJECT_DIR"
        flutter test "test/$test_file" $update_flag --reporter=compact
        echo -e "${GREEN}✅ ${description} selesai!${NC}"
    else
        echo -e "${RED}❌ File test tidak ditemukan: $test_file${NC}"
        exit 1
    fi
}

run_component_galleries() {
    local mode=${1:-verify}

    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🧩 Running: Chat Component Galleries (${mode})${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    cd "$PROJECT_DIR"
    case "$mode" in
        update)
            bash "$SCRIPT_DIR/run_chat_component_smoke.sh" update
            ;;
        *)
            bash "$SCRIPT_DIR/run_chat_component_smoke.sh" goldens
            ;;
    esac

    echo -e "${GREEN}✅ Chat Component Galleries selesai!${NC}"
}

# Main script
case "${1:-all}" in
    all)
        echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║   🚀 Menjalankan SEMUA Golden Tests                  ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
        
        run_test "golden_auth_screens_test.dart" "Layar Autentikasi"
        run_test "golden_main_screens_test.dart" "Layar Utama"
        run_test "golden_chat_screens_test.dart" "Layar Chat"
        run_component_galleries
        run_test "golden_admin_feedback_screens_test.dart" "Admin & Feedback"
        run_test "golden_security_screens_test.dart" "Security (Pattern Lock)"
        run_test "golden_additional_screens_test.dart" "Layar Tambahan"
        
        echo -e "\n${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   ✅ SEMUA GOLDEN TESTS SELESAI!                     ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
        ;;
    
    auth)
        run_test "golden_auth_screens_test.dart" "Layar Autentikasi" "${2:-}"
        ;;
    
    main)
        run_test "golden_main_screens_test.dart" "Layar Utama" "${2:-}"
        ;;
    
    chat)
        run_test "golden_chat_screens_test.dart" "Layar Chat" "${2:-}"
        ;;

    components)
        if [ "${2:-}" = "--update-goldens" ]; then
            run_component_galleries update
        else
            run_component_galleries
        fi
        ;;
    
    admin)
        run_test "golden_admin_feedback_screens_test.dart" "Admin & Feedback" "${2:-}"
        ;;
    
    security)
        run_test "golden_security_screens_test.dart" "Security (Pattern Lock)" "${2:-}"
        ;;
    
    additional)
        run_test "golden_additional_screens_test.dart" "Layar Tambahan" "${2:-}"
        ;;
    
    update)
        echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║   📸 Update SEMUA Golden Baseline Screenshots        ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
        echo -e "${YELLOW}⚠️  Ini akan meng-overwrite semua baseline screenshots!${NC}"
        echo -e "${YELLOW}   Pastikan perubahan UI memang disengaja.${NC}"
        echo ""
        
        run_test "golden_auth_screens_test.dart" "Update: Layar Autentikasi" "--update-goldens"
        run_test "golden_main_screens_test.dart" "Update: Layar Utama" "--update-goldens"
        run_test "golden_chat_screens_test.dart" "Update: Layar Chat" "--update-goldens"
        run_component_galleries update
        run_test "golden_admin_feedback_screens_test.dart" "Update: Admin & Feedback" "--update-goldens"
        run_test "golden_security_screens_test.dart" "Update: Security" "--update-goldens"
        run_test "golden_additional_screens_test.dart" "Update: Layar Tambahan" "--update-goldens"
        
        echo -e "\n${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   ✅ SEMUA BASELINE BERHASIL DIUPDATE!               ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
        echo -e "\n${YELLOW}💡 Jangan lupa commit perubahan:${NC}"
        echo -e "   git add test/goldens/"
        echo -e "   git commit -m \"chore: update golden baseline screenshots\""
        ;;
    
    verify)
        echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║   🔍 Verifikasi Golden Tests (No Update)             ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
        echo -e "${YELLOW}⚠️  Mode verifikasi - akan gagal jika ada perbedaan${NC}"
        echo ""
        
        run_test "golden_auth_screens_test.dart" "Verify: Layar Autentikasi"
        run_test "golden_main_screens_test.dart" "Verify: Layar Utama"
        run_test "golden_chat_screens_test.dart" "Verify: Layar Chat"
        run_component_galleries
        run_test "golden_admin_feedback_screens_test.dart" "Verify: Admin & Feedback"
        run_test "golden_security_screens_test.dart" "Verify: Security"
        run_test "golden_additional_screens_test.dart" "Verify: Layar Tambahan"
        
        echo -e "\n${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   ✅ VERIFIKASI BERHASIL - Tidak Ada Perubahan!      ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
        ;;
    
    help|--help|-h)
        show_help
        ;;
    
    *)
        echo -e "${RED}❌ Option tidak dikenal: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
