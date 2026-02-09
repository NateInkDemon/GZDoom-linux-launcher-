#!/bin/bash

# --- Launcher little colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color (Reset)

# --- Path Setup ---
BASE_DIR="$HOME/Games/Doom"
IWAD_DIR="$BASE_DIR/iwads"
MODS_DIR="$BASE_DIR/mods"

# Make sure folders actually exist
mkdir -p "$IWAD_DIR" "$MODS_DIR"

clear

# --- Check for WADS ---
if [ ! "$(ls -A $IWAD_DIR/*.wad 2>/dev/null)" ]; then
    echo -e "${YELLOW}No WADs found. Wanna grab Freedoom real quick? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Checking what Distro you're rocking...${NC}"

        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case $ID in
                arch|manjaro|endeavouros)
                    echo -e "${GREEN}Arch Linux detected${NC}"
                    sudo pacman -S --noconfirm freedoom1 freedoom2
                    ln -sf /usr/share/doom/freedoom1.wad "$IWAD_DIR/"
                    ln -sf /usr/share/doom/freedoom2.wad "$IWAD_DIR/"
                    ;;
                fedora)
                    echo -e "${GREEN}Fedora detected.${NC}"
                    sudo dnf install -y freedoom-phase1 freedoom-phase2
                    ln -sf /usr/share/doom/freedoom*.wad "$IWAD_DIR/"
                    ;;
                ubuntu|debian|pop|linuxmint)
                    echo -e "${GREEN}Debian/Ubuntu base detected.${NC}"
                    sudo apt update && sudo apt install -y freedoom
                    ln -sf /usr/share/games/doom/freedoom*.wad "$IWAD_DIR/"
                    ;;
                *)
                    echo -e "${RED}You're using a distro that not even Linus Torvalds knows about${NC}"
                    echo "Trying manual download from GitHub..."
                    curl -L https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip -o fd.zip
                    unzip -j fd.zip "*.wad" -d "$IWAD_DIR/" && rm fd.zip
                    ;;
            esac
            echo -e "${GREEN}Freedoom is ready to go!${NC}"
        fi
    fi
fi

# --- WELCOME BANNER ---
echo -e "${RED}========================================${NC}"
echo -e "${YELLOW}         GZDoom for Linux               ${NC}"
echo -e "${RED}========================================${NC}"
echo -e "${CYAN} Thanks for installing! Let's get it. Hit Enter to continue:${NC}"
read -p ""

# --- Check for engine ---
if ! command -v gzdoom &> /dev/null && ! command -v zandronum &> /dev/null && ! command -v zdoom &> /dev/null; then
    echo -e "${YELLOW}You didn't read the README, you total noob. Here, pick one:${NC}"
    echo -e "1) ${GREEN}GZDoom${NC} (Standard, for decent PCs)"
    echo -e "2) ${PURPLE}ZDoom${NC} (For potato/old-school PCs)"
    echo -e "3) ${BLUE}Zandronum${NC} (If you wanna play Online)"
    read -p "Pick your engine to install: " ENGINE_CHOICE

    . /etc/os-release
    case $ENGINE_CHOICE in
        1) PKG="gzdoom" ;;
        2) PKG="zdoom" ;;
        3) PKG="zandronum" ;;
        *) echo "Invalid choice, peace out."; exit 1 ;;
    esac

    echo -e "${CYAN}Installing $PKG for $ID...${NC}"
    case $ID in
        arch|manjaro|endeavouros) sudo pacman -S --noconfirm $PKG ;;
        fedora) sudo dnf install -y $PKG ;;
        ubuntu|debian|pop|linuxmint) sudo apt update && sudo apt install -y $PKG ;;
    esac
fi

# --- SET THE ENGINE ---
if command -v gzdoom &> /dev/null; then
    ENGINE="gzdoom"
elif command -v zandronum &> /dev/null; then
    ENGINE="zandronum"
elif command -v zdoom &> /dev/null; then
    ENGINE="zdoom"
else
    echo -e "${RED}Error: No engine found!${NC}"
    exit 1
fi

echo -e "${GREEN}Get your custom MODS and WADS here:${NC}"
echo -e "${BLUE}>> ModDB: ${NC}https://www.moddb.com/games/doom/mods"
echo -e "${PURPLE}No WADs? No problem. You'll be running Freedoom by default.${NC}"
echo -e "${RED}========================================${NC}"
echo ""
sleep 1

# 1. WAD PICKER
echo -e "${YELLOW}--- Pick your WAD ---${NC}"
cd "$IWAD_DIR" || { echo -e "${RED}Error: wads folder is missing!${NC}"; exit 1; }

mapfile -t IWAD_LIST < <(ls *.wad 2>/dev/null)

if [ ${#IWAD_LIST[@]} -eq 0 ]; then
    echo -e "${RED}No WADs found in $IWAD_DIR.${NC}"
    echo "Drop your WADS in the folder or check your Freedoom installation."
    exit 1
fi

PS3=$(echo -e "${CYAN}Choose your fate (number): ${NC}")
select WAD in "${IWAD_LIST[@]}" "EXIT"; do
    if [ "$WAD" == "EXIT" ]; then exit; fi
    if [ -n "$WAD" ]; then break; fi
done

# 2. MOD PICKER
echo ""
echo -e "${YELLOW}--- CHOOSE YOUR MODS ---${NC}"
echo -e "${CYAN}Type the numbers separated by spaces (ex: 1 3)${NC}"
echo -e "${CYAN}Or just smash ENTER key to play Vanilla.${NC}"
echo "----------------------------------------"

cd "$MODS_DIR" || exit
mapfile -t MOD_LIST < <(ls *.pk3 *.wad *.zip 2>/dev/null)

if [ ${#MOD_LIST[@]} -eq 0 ]; then
    echo -e "${PURPLE}(No mods found in $MODS_DIR)${NC}"
else
    for i in "${!MOD_LIST[@]}"; do
        printf "${GREEN}%2d)${NC} %s\n" $((i+1)) "${MOD_LIST[$i]}"
    done
fi

echo "----------------------------------------"
read -p "$(echo -e ${YELLOW}Selection: ${NC})" -a CHOICES

# 3. BUILD THE LOAD ORDER
SELECTED_MODS_PARAMS=""
for INDEX in "${CHOICES[@]}"; do
    ACTUAL_INDEX=$((INDEX-1))
    if [ -n "${MOD_LIST[$ACTUAL_INDEX]}" ]; then
        SELECTED_MODS_PARAMS="$SELECTED_MODS_PARAMS -file $MODS_DIR/${MOD_LIST[$ACTUAL_INDEX]}"
    fi
done

# 4. RUN THE GAME
echo -e "\n${RED}Rip and tear, brother.${NC}"

# Using the detected engine variable
$ENGINE -iwad "$IWAD_DIR/$WAD" $SELECTED_MODS_PARAMS
