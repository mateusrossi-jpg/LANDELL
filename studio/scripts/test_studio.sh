#!/usr/bin/env bash
# ==============================================================================
# ENDAP STUDIO — UNIFIED AUTOMATED TEST SUITE RUNNER
# Suíte Oficial de Testes Automatizados Industriais
# ==============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

# Cores industriais
C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_BOLD='\033[1m'
C_RESET='\033[0m'

print_header() {
    echo -e "${C_CYAN}==============================================================================${C_RESET}"
    echo -e "${C_BOLD}🚀 ENDAP STUDIO — SUÍTE DE TESTES AUTOMATIZADOS${C_RESET}"
    echo -e "${C_CYAN}==============================================================================${C_RESET}"
}

run_suite() {
    local target="$1"
    local desc="$2"
    echo -e "\n${C_BOLD}${C_YELLOW}▶ EXECUTANDO:${C_RESET} ${desc} (${target})"
    local start_time=$(date +%s)
    
    if flutter test "$target"; then
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        echo -e "${C_GREEN}✔ [APROVADO]${C_RESET} ${desc} (${elapsed}s)\n"
    else
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        echo -e "${C_RED}✖ [FALHOU]${C_RESET} ${desc} (${elapsed}s)\n"
        exit 1
    fi
}

run_live_hardware() {
    local ip="${1:-192.168.0.27}"
    echo -e "\n${C_BOLD}${C_YELLOW}▶ EXECUTANDO AGENTES DE HARDWARE REAL:${C_RESET} http://${ip}"
    if [ -f "scripts/run_live_hardware_agents.py" ]; then
        python3 scripts/run_live_hardware_agents.py "http://${ip}"
    else
        echo -e "${C_RED}Script scripts/run_live_hardware_agents.py não encontrado.${C_RESET}"
        exit 1
    fi
}

print_header

MODE="${1:---all}"

case "$MODE" in
    --unit)
        run_suite "test/unit" "Testes Unitários & Compilador Bytecode"
        ;;
    --services)
        run_suite "test/services" "Serviços de Rede, Descoberta e Telemetria"
        ;;
    --widgets)
        run_suite "test/widgets" "Componentes Visuais, Diálogos & Widgets Industriais"
        ;;
    --personas)
        run_suite "test/personas" "Visões Operacionais (Home, Ladder, Manutenção, Gestor, Redes)"
        ;;
    --use-cases)
        run_suite "test/use_cases" "Agentes de Casos de Uso (Do Provisionamento ao Forçamento Real)"
        ;;
    --live)
        run_live_hardware "$2"
        ;;
    --all)
        echo -e "${C_BOLD}Iniciando bateria completa (Unitários, Serviços, Widgets, Personas, Casos de Uso)...${C_RESET}"
        run_suite "test/unit" "1/5. Testes Unitários & Compilador Bytecode"
        run_suite "test/services" "2/5. Serviços de Rede & Telemetria"
        run_suite "test/widgets" "3/5. Widgets & Componentes Industriais"
        run_suite "test/personas" "4/5. Visões Operacionais das Personas"
        run_suite "test/use_cases" "5/5. Agentes Especializados de Casos de Uso"
        echo -e "${C_CYAN}==============================================================================${C_RESET}"
        echo -e "${C_GREEN}${C_BOLD}🎉 TODAS AS 5 SUÍTES DO ENDAP STUDIO FORAM 100% APROVADAS!${C_RESET}"
        echo -e "${C_CYAN}==============================================================================${C_RESET}"
        ;;
    *)
        echo -e "Uso: $0 [--unit | --services | --widgets | --personas | --use-cases | --live [IP] | --all]"
        exit 1
        ;;
esac
