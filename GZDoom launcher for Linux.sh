#!/bin/bash

# --- Los colorcitos del launcher ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color (Reset)

# --- Como se organizan las rutas ---
BASE_DIR="$HOME/Games/Doom"
IWAD_DIR="$BASE_DIR/iwads"
MODS_DIR="$BASE_DIR/mods"

# Ver que existan las carpetas
mkdir -p "$IWAD_DIR" "$MODS_DIR"

clear

# --- Ver si exsten WADS, si no, descargar Freedoom ---
if [ ! "$(ls -A $IWAD_DIR/*.wad 2>/dev/null)" ]; then
    echo -e "${YELLOW}No se detectaron WADs. ¿Quieres descargar Freedoom? (s/n)${NC}"
    read -r respuesta
    if [[ "$respuesta" =~ ^[Ss]$ ]]; then
        echo -e "${CYAN}A ver que Distro usas...${NC}"

        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case $ID in
                arch|manjaro|endeavouros)
                    echo -e "${GREEN}Arch Linux detectado${NC}"
                    sudo pacman -S --noconfirm freedoom1 freedoom2
                    ln -sf /usr/share/doom/freedoom1.wad "$IWAD_DIR/"
                    ln -sf /usr/share/doom/freedoom2.wad "$IWAD_DIR/"
                    ;;
                fedora)
                    echo -e "${GREEN}Fedora detectado.${NC}"
                    sudo dnf install -y freedoom-phase1 freedoom-phase2
                    ln -sf /usr/share/doom/freedoom*.wad "$IWAD_DIR/"
                    ;;
                ubuntu|debian|pop|linuxmint)
                    echo -e "${GREEN}Base Debian/Ubuntu detectada.${NC}"
                    sudo apt update && sudo apt install -y freedoom
                    ln -sf /usr/share/games/doom/freedoom*.wad "$IWAD_DIR/"
                    ;;
                *)
                    echo -e "${RED}Usas una distro que no usa ni Linus Torvald${NC}"
                    echo "Intentando descarga manual desde github..."
                    curl -L https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip -o fd.zip
                    unzip -j fd.zip "*.wad" -d "$IWAD_DIR/" && rm fd.zip
                    ;;
            esac
            echo -e "${GREEN}Freedoom se ha descargado, si no lo hizo y te dio error, descargalo de google y ponlo en la carpeta que le corresponde${NC}"
        fi
    fi
fi

# --- MENSAJE DE BIENVENIDA ---
echo -e "${RED}========================================${NC}"
echo -e "${YELLOW}        GZDoom for Linux               ${NC}"
echo -e "${RED}========================================${NC}"
echo -e "${CYAN} Gracias por instalarlo, vamo a dale, presiona enter para continuar:${NC}"
read -p ""


# --- Aver si leyeron el Leeme ---
if ! command -v gzdoom &> /dev/null && ! command -v zandronum &> /dev/null && ! command -v zdoom &> /dev/null; then
    echo -e "${YELLOW}No leiste el leeme, sos un bobolongo aqui tenes:${NC}"
    echo -e "1) ${GREEN}GZDoom${NC} (El estándar, PC buena)"
    echo -e "2) ${PURPLE}ZDoom${NC} (Para PCs malas/chotas)"
    echo -e "3) ${BLUE}Zandronum${NC} (Si quieres jugar Online)"
    read -p "Elige una opción para instalar: " ENGINE_CHOICE

    . /etc/os-release
    case $ENGINE_CHOICE in
        1) PKG="gzdoom" ;;
        2) PKG="zdoom" ;;
        3) PKG="zandronum" ;;
        *) echo "Opción no válida"; exit 1 ;;
    esac

    echo -e "${CYAN}Instalando $PKG para $ID...${NC}"
    case $ID in
        arch|manjaro|endeavouros) sudo pacman -S --noconfirm $PKG ;;
        fedora) sudo dnf install -y $PKG ;;
        ubuntu|debian|pop|linuxmint) sudo apt update && sudo apt install -y $PKG ;;
    esac
fi

# Definir cuál motor usar para el resto del script
if command -v gzdoom &> /dev/null; then ENGINE="gzdoom";
elif command -v zandronum &> /dev/null; then ENGINE="zandronum";

echo -e "${GREEN}Descarga tus MODS y WADS aquí:${NC}"
echo -e "${BLUE}>> ModDB: ${NC}https://www.moddb.com/games/doom/mods"
echo -e "${PURPLE}Si aún no tienes tus wads, estarás usando Freedoom por defecto${NC}"
echo -e "${RED}========================================${NC}"
echo ""

sleep 1

# 1. SELECCIONADOR DE TUS WADS
echo -e "${YELLOW}--- Selecciona tu WAD ---${NC}"
cd "$IWAD_DIR" || { echo -e "${RED}Error: No se encontró la carpeta iwads${NC}"; exit 1; }

mapfile -t IWAD_LIST < <(ls *.wad 2>/dev/null)

if [ ${#IWAD_LIST[@]} -eq 0 ]; then
    echo -e "${RED}No se encontraron WADs en $IWAD_DIR.${NC}"
    echo "Pon tus wads en su carpeta correspondiente o revisa que Freedoom este en su carpeta"
    exit 1
fi

# Personalización del prompt de selección
PS3=$(echo -e "${CYAN}Elige tu destino (número): ${NC}")
select WAD in "${IWAD_LIST[@]}" "SALIR"; do
    if [ "$WAD" == "SALIR" ]; then exit; fi
    if [ -n "$WAD" ]; then break; fi
done

# 2. SELECCIÓN DE MODS
echo ""
echo -e "${YELLOW}--- SELECCIONA TUS MODS ---${NC}"
echo -e "${CYAN}Escribe los números separados por espacios (ej: 1 3)${NC}"
echo -e "${CYAN}O puedes darle a ENTER para jugar sin mods (vanilla).${NC}"
echo "----------------------------------------"

cd "$MODS_DIR" || exit
mapfile -t MOD_LIST < <(ls *.pk3 *.wad *.zip 2>/dev/null)

if [ ${#MOD_LIST[@]} -eq 0 ]; then
    echo -e "${PURPLE}(No se encontraron mods en $MODS_DIR)${NC}"
else
    for i in "${!MOD_LIST[@]}"; do
        printf "${GREEN}%2d)${NC} %s\n" $((i+1)) "${MOD_LIST[$i]}"
    done
fi

echo "----------------------------------------"
read -p "$(echo -e ${YELLOW}Elección: ${NC})" -a CHOICES

# 3. CONSTRUCCIÓN DEL ORDEN DE CARGA
SELECTED_MODS_PARAMS=""
for INDEX in "${CHOICES[@]}"; do
    ACTUAL_INDEX=$((INDEX-1))
    if [ -n "${MOD_LIST[$ACTUAL_INDEX]}" ]; then
        SELECTED_MODS_PARAMS="$SELECTED_MODS_PARAMS -file $MODS_DIR/${MOD_LIST[$ACTUAL_INDEX]}"
    fi
done

# 4. EJECUTAR EL JUEGO
echo ""
echo -e "${RED}Mata y desgarra,compañero${NC}"
gzdoom -iwad "$IWAD_DIR/$WAD" $SELECTED_MODS_PARAMS
