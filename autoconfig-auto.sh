#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Create a backup directory for the current date/time
BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$HOME/.fx-autoconfig-backups/$BACKUP_DATE"

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
        OS="windows"
    else
        OS="linux"
    fi
    echo -e "${BLUE}Detected operating system:${NC} $OS"
}

print_header() {
    echo -e "\n${BLUE}=============================================${NC}"
    echo -e "${BLUE}   fx-autoconfig Interactive Installer${NC}"
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${YELLOW}This script will help you install fx-autoconfig for Firefox-based browsers${NC}"
    echo -e "${YELLOW}fx-autoconfig allows you to run custom JavaScript in your browser${NC}\n"
}

# Function to create backups
backup_file() {
    local file=$1
    local backup_path

    if [[ "$OS" == "windows" ]]; then
        # Convert Windows path to a structure suitable for the backup directory
        backup_path="$BACKUP_DIR/$(echo "${file//\\//}" | sed 's/://')"
    else
        backup_path="$BACKUP_DIR/$(dirname "$file" | sed 's/^\///')"
    fi

    if [ -f "$file" ]; then
        mkdir -p "$backup_path"
        cp "$file" "$backup_path/"
        echo -e "${GREEN}✓ Backed up:${NC} $file → $backup_path/$(basename "$file")"
    fi
}

restore_backup() {
    local selected_backup

    if [ ! -d "$HOME/.fx-autoconfig-backups" ]; then
        echo -e "${RED}No backups found.${NC}"
        return 1
    fi

    echo -e "\n${BLUE}Available backups:${NC}"

    # List available backups
    local i=1
    local backups=()

    while read -r backup; do
        echo -e "${CYAN}$i)${NC} $(basename "$backup")"
        backups+=("$backup")
        ((i++))
    done < <(find "$HOME/.fx-autoconfig-backups" -mindepth 1 -maxdepth 1 -type d | sort -r)

    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}No backups found.${NC}"
        return 1
    fi

    echo -e "${YELLOW}Enter the number of the backup to restore (or 'q' to quit):${NC}"
    read -r choice

    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        return 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ]; then
        echo -e "${RED}Invalid choice.${NC}"
        return 1
    fi

    selected_backup="${backups[$((choice-1))]}"
    echo -e "${YELLOW}Restoring backup from:${NC} $selected_backup"

    # Find and restore program files
    find "$selected_backup" -type f -name "config.js" | while read -r config_js; do
        local rel_path=$(echo "$config_js" | sed "s|$selected_backup/||")
        local target

        if [[ "$OS" == "windows" ]]; then
            # Convert back to Windows path format
            drive_letter=$(echo "$rel_path" | cut -d'/' -f1)
            rest_of_path=$(echo "$rel_path" | cut -d'/' -f2-)
            target="$drive_letter:/$rest_of_path"
            target="${target//\//\\}"
        else
            target="/$rel_path"
        fi

        local target_dir=$(dirname "$target")

        if [ -n "$BROWSER_PATH" ] && [[ "$target" == *"$BROWSER_PATH"* ]]; then
            echo -e "${YELLOW}Restoring:${NC} $target"
            if [[ "$OS" == "windows" ]]; then
                mkdir -p "$target_dir"
                cp "$config_js" "$target"
            else
                sudo mkdir -p "$target_dir"
                sudo cp "$config_js" "$target"
            fi
        fi
    done

    # Find and restore config-prefs.js files
    find "$selected_backup" -type f -name "config-prefs.js" | while read -r prefs_js; do
        local rel_path=$(echo "$prefs_js" | sed "s|$selected_backup/||")
        local target

        if [[ "$OS" == "windows" ]]; then
            # Convert back to Windows path format
            drive_letter=$(echo "$rel_path" | cut -d'/' -f1)
            rest_of_path=$(echo "$rel_path" | cut -d'/' -f2-)
            target="$drive_letter:/$rest_of_path"
            target="${target//\//\\}"
        else
            target="/$rel_path"
        fi

        local target_dir=$(dirname "$target")

        if [ -n "$BROWSER_PATH" ] && [[ "$target" == *"$BROWSER_PATH"* ]]; then
            echo -e "${YELLOW}Restoring:${NC} $target"
            if [[ "$OS" == "windows" ]]; then
                mkdir -p "$target_dir"
                cp "$prefs_js" "$target"
            else
                sudo mkdir -p "$target_dir"
                sudo cp "$prefs_js" "$target"
            fi
        fi
    done

    # Find and restore profile files
    if [ -n "$PROFILE_PATH" ]; then
        for dir in chrome chrome/utils chrome/JS chrome/CSS chrome/resources; do
            if [ -d "$selected_backup/$PROFILE_PATH/$dir" ]; then
                echo -e "${YELLOW}Restoring profile directory:${NC} $dir"
                mkdir -p "$PROFILE_PATH/$dir"
                cp -r "$selected_backup/$PROFILE_PATH/$dir"/* "$PROFILE_PATH/$dir/" 2>/dev/null
            fi
        done

        # Remove startup cache to ensure changes take effect
        rm -rf "$PROFILE_PATH/startupCache" 2>/dev/null
        rm -rf "$PROFILE_PATH/cache2" 2>/dev/null
    fi

    echo -e "${GREEN}Backup restoration complete!${NC}"
    return 0
}

# Function to detect Firefox-based browsers
detect_browsers() {
    echo -e "${BLUE}Detecting Firefox-based browsers...${NC}"

    local browsers=()
    local browser_paths=()
    local browser_names=()
    local unique_paths=()

    if [[ "$OS" == "windows" ]]; then
        # Windows browser detection
        local win_locations=(
            "/c/Program Files/Mozilla Firefox"
            "/c/Program Files (x86)/Mozilla Firefox"
            "/c/Program Files/Waterfox"
            "/c/Program Files (x86)/Waterfox"
            "/c/Program Files/LibreWolf"
            "/c/Program Files (x86)/LibreWolf"
            "/c/Program Files/Zen Browser"
            "/c/Program Files (x86)/Zen Browser"
            "/c/Program Files/Zen Twilight"
            "/c/Program Files (x86)/Zen Twilight"
        )

        # Convert Windows paths to proper format if not running in WSL/Cygwin
        if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "cygwin" ]]; then
            local win_real_locations=(
                "C:\\Program Files\\Mozilla Firefox"
                "C:\\Program Files (x86)\\Mozilla Firefox"
                "C:\\Program Files\\Waterfox"
                "C:\\Program Files (x86)\\Waterfox"
                "C:\\Program Files\\LibreWolf"
                "C:\\Program Files (x86)\\LibreWolf"
                "C:\\Program Files\\Zen Browser"
                "C:\\Program Files (x86)\\Zen Browser"
                "C:\\Program Files\\Zen Twilight"
                "C:\\Program Files (x86)\\Zen Twilight"
            )

            # Check for Zen browsers using registry as a fallback
            if command -v reg &>/dev/null; then
                echo -e "${BLUE}Checking Windows registry for browser installations...${NC}"
                # Try to find Zen Browser from registry
                zen_path=$(reg query "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\zenbrowser.exe" /ve 2>/dev/null | grep -i "REG_SZ" | awk '{print $3}')
                if [ -n "$zen_path" ]; then
                    win_real_locations+=("$(dirname "$zen_path")")
                fi

                # Try to find Zen Twilight from registry
                zen_twilight_path=$(reg query "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\zentwilight.exe" /ve 2>/dev/null | grep -i "REG_SZ" | awk '{print $3}')
                if [ -n "$zen_twilight_path" ]; then
                    win_real_locations+=("$(dirname "$zen_twilight_path")")
                fi
            fi
        fi

        local locations=()
        if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
            locations=("${win_locations[@]}")
        else
            locations=("${win_real_locations[@]}")
        fi
    else
        # Linux detection
        local locations=(
            "/usr/lib/firefox"
            "/usr/lib64/firefox"
            "/opt/firefox"
            "/usr/lib/firefox-esr"
            "/opt/waterfox"
            "/opt/librewolf"
            "/opt/zen-browser"
            "/opt/zen-browser-bin"
            "/opt/zen-twilight"
            "/opt/zen-twilight-bin"
            "/Applications/Firefox.app/Contents/MacOS"
            "/Applications/Firefox Nightly.app/Contents/Resources"
        )

        # Also check for any executables in /opt with firefox/zen in the name
        mapfile -t opt_browsers < <(find /opt -maxdepth 2 -name "*firefox*" -type d 2>/dev/null)
        mapfile -t zen_browsers < <(find /opt -maxdepth 2 -name "*zen*" -type d 2>/dev/null)

        locations+=("${opt_browsers[@]}" "${zen_browsers[@]}")
    fi

    # Look for browser binaries in these locations
    local i=1
    for loc in "${locations[@]}"; do
        # Skip if directory doesn't exist
        [ ! -d "$loc" ] && continue

        # Define executable names based on OS
        local exe_extensions=()
        if [[ "$OS" == "windows" ]]; then
            exe_extensions=(".exe")
        else
            exe_extensions=("" "-bin")
        fi

        # Check for Firefox-style browsers
        local is_firefox_based=false
        if [ -f "$loc/application.ini" ] || [ -f "$loc/omni.ja" ]; then
            is_firefox_based=true
        else
            # Check for executables
            for ext in "${exe_extensions[@]}"; do
                if [ -f "$loc/firefox$ext" ] || [ -f "$loc/zentwilight$ext" ] || [ -f "$loc/zenbrowser$ext" ] || [ -f "$loc/zen$ext" ]; then
                    is_firefox_based=true
                    break
                fi
            done
        fi

        # Verify it's truly a Zen browser if that's what we think it is
        if [[ "$is_firefox_based" == true && ("$loc" == *"zen"* || "$loc" == *"Zen"*) ]]; then
            # Additional verification for Zen browsers to avoid false positives
            local is_zen_browser=false

            # Check for Zen-specific files or executables
            for ext in "${exe_extensions[@]}"; do
                if [ -f "$loc/zenbrowser$ext" ] || [ -f "$loc/zentwilight$ext" ] || [ -f "$loc/zen$ext" ]; then
                    is_zen_browser=true
                    break
                fi
            done

            # If it claims to be Zen but doesn't have Zen executables, verify further
            if [[ "$is_zen_browser" == false ]]; then
                # Check browser.ini or other Zen-specific identifiers
                if [ -f "$loc/browser/browser.ini" ]; then
                    grep -q "ZenBrowser" "$loc/browser/browser.ini" && is_zen_browser=true
                fi
            fi

            # Skip if we can't verify it's a Zen browser
            if [[ "$is_zen_browser" == false ]]; then
                echo -e "${YELLOW}Skipping potential false positive Zen browser at:${NC} $loc"
                continue
            fi
        fi

        if [[ "$is_firefox_based" == true ]]; then
            # Determine the browser name
            local name
            if [[ "$loc" == *"firefox-esr"* ]]; then
                name="Firefox ESR"
            elif [[ "$loc" == *"firefox-beta"* || "$loc" == *"firefox-developer"* ]]; then
                name="Firefox Beta"
            elif [[ "$loc" == *"firefox"* || "$loc" == *"Firefox"* ]]; then
                name="Firefox"
            elif [[ "$loc" == *"waterfox"* || "$loc" == *"Waterfox"* ]]; then
                name="Waterfox"
            elif [[ "$loc" == *"librewolf"* || "$loc" == *"LibreWolf"* ]]; then
                name="LibreWolf"
            elif [[ "$loc" == *"zen-twilight"* || "$loc" == *"Zen Twilight"* ]]; then
                name="Zen Twilight"
            elif [[ "$loc" == *"zen-browser"* || "$loc" == *"Zen Browser"* ]]; then
                name="Zen Browser"
            elif [[ "$loc" == *"zen"* || "$loc" == *"Zen"* ]]; then
                name="Zen Browser"
            else
                name="Unknown Firefox-based browser"
            fi

            # Check if we've already seen this path
            local is_duplicate=false
            for existing_path in "${unique_paths[@]}"; do
                if [ "$existing_path" == "$loc" ]; then
                    is_duplicate=true
                    break
                fi
            done

            # Only add if it's not a duplicate
            if [ "$is_duplicate" = false ]; then
                unique_paths+=("$loc")
                browsers+=("$i) $name ($loc)")
                browser_paths+=("$loc")
                browser_names+=("$name")
                ((i++))
            fi
        fi
    done

    if [ ${#browsers[@]} -eq 0 ]; then
        echo -e "${RED}No Firefox-based browsers found.${NC}"
        echo -e "${YELLOW}You may need to specify the path manually.${NC}"
        return 1
    fi

    echo -e "\n${BLUE}Found the following browsers:${NC}"
    for browser in "${browsers[@]}"; do
        echo -e "${CYAN}$browser${NC}"
    done

    echo -e "\n${YELLOW}Enter the number of the browser to install fx-autoconfig for (or 'm' for manual entry, 'q' to quit):${NC}"
    read -r choice

    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo -e "${YELLOW}Exiting...${NC}"
        exit 0
    fi

    if [[ "$choice" == "m" || "$choice" == "M" ]]; then
        echo -e "${YELLOW}Enter the full path to your browser installation directory:${NC}"
        read -r BROWSER_PATH
        echo -e "${YELLOW}Enter a name for this browser:${NC}"
        read -r BROWSER_NAME

        if [ ! -d "$BROWSER_PATH" ]; then
            echo -e "${RED}Directory does not exist.${NC}"
            return 1
        fi
    else
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#browsers[@]} ]; then
            echo -e "${RED}Invalid choice.${NC}"
            return 1
        fi

        BROWSER_PATH="${browser_paths[$((choice-1))]}"
        BROWSER_NAME="${browser_names[$((choice-1))]}"
    fi

    echo -e "${GREEN}Selected:${NC} $BROWSER_NAME at $BROWSER_PATH"
    return 0
}

# Function to detect profiles
detect_profiles() {
    echo -e "\n${BLUE}Detecting browser profiles...${NC}"

    local profile_dirs=()
    local profile_names=()
    local profile_paths=()

    if [[ "$OS" == "windows" ]]; then
        # Windows profile detection locations
        local appdata="${APPDATA:-$HOME/AppData/Roaming}"
        local localappdata="${LOCALAPPDATA:-$HOME/AppData/Local}"

        local default_profile_dirs=(
            "$appdata/Mozilla/Firefox/Profiles"
            "$localappdata/Mozilla/Firefox/Profiles"
            "$appdata/Zen Browser/Profiles"
            "$appdata/Zen Twilight/Profiles"
            "$appdata/Waterfox/Profiles"
            "$appdata/LibreWolf/Profiles"
        )

        # Try to find Zen-specific profiles for Zen browsers
        if [[ "$BROWSER_NAME" == *"Zen"* ]]; then
            default_profile_dirs+=("$appdata/Zen Browser/Profiles" "$appdata/Zen Twilight/Profiles")
        fi
    else
        # Linux profile detection locations
        local mozilla_dir="$HOME/.mozilla"
        local default_profile_dirs=(
            "$HOME/.mozilla/firefox"
            "$HOME/.zen"
            "$HOME/.zen-browser"
            "$HOME/.zen-twilight"
            "$HOME/.librewolf"
            "$HOME/.waterfox"
            "$HOME/.config/firefox"
        )

        # Add browser-specific locations
        if [[ "$BROWSER_NAME" == *"Zen"* ]]; then
            default_profile_dirs+=("$HOME/.zen")
        fi
    fi

    # Find all profile directories
    local found=false
    for dir in "${default_profile_dirs[@]}"; do
        if [ -d "$dir" ]; then
            # Look for profile directories (they usually have a .default or random string in the name)
            while read -r profile_dir; do
                # Skip if not a directory
                [ ! -d "$profile_dir" ] && continue

                local dir_name=$(basename "$profile_dir")
                local profile_name="Unknown"

                # Try to get profile name from profiles.ini if it exists
                if [ -f "$dir/profiles.ini" ]; then
                    local name=$(grep -A 10 -B 10 "$dir_name" "$dir/profiles.ini" | grep "Name=" | head -n 1 | cut -d'=' -f2)
                    if [ -n "$name" ]; then
                        profile_name="$name"
                    fi
                fi

                # If name is still unknown, try to guess from directory name
                if [ "$profile_name" == "Unknown" ]; then
                    if [[ "$dir_name" == *"default"* ]]; then
                        profile_name="Default Profile"
                    elif [[ "$dir_name" == *"dev-edition"* ]]; then
                        profile_name="Developer Edition"
                    else
                        profile_name="$dir_name"
                    fi
                fi

                profile_dirs+=("$profile_dir")
                profile_names+=("$profile_name")
                found=true
            done < <(find "$dir" -maxdepth 1 -type d ! -name ".")
        fi
    done

    if ! $found; then
        echo -e "${YELLOW}No profiles found automatically.${NC}"
        echo -e "${YELLOW}You may need to specify the path manually.${NC}"

        echo -e "${YELLOW}Enter the full path to your browser profile directory (or 'q' to quit):${NC}"
        read -r manual_path

        if [[ "$manual_path" == "q" || "$manual_path" == "Q" ]]; then
            echo -e "${YELLOW}Exiting...${NC}"
            exit 0
        fi

        if [ ! -d "$manual_path" ]; then
            echo -e "${RED}Directory does not exist.${NC}"
            return 1
        fi

        PROFILE_PATH="$manual_path"
        echo -e "${GREEN}Selected profile:${NC} $PROFILE_PATH"
        return 0
    fi

    echo -e "\n${BLUE}Found the following profiles:${NC}"
    for i in "${!profile_dirs[@]}"; do
        echo -e "${CYAN}$((i+1))) ${profile_names[i]} (${profile_dirs[i]})${NC}"
    done

    echo -e "\n${YELLOW}Enter the number of the profile to install fx-autoconfig for (or 'm' for manual entry, 'q' to quit):${NC}"
    read -r choice

    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo -e "${YELLOW}Exiting...${NC}"
        exit 0
    fi

    if [[ "$choice" == "m" || "$choice" == "M" ]]; then
        echo -e "${YELLOW}Enter the full path to your browser profile directory:${NC}"
        read -r PROFILE_PATH

        if [ ! -d "$PROFILE_PATH" ]; then
            echo -e "${RED}Directory does not exist.${NC}"
            return 1
        fi
    else
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#profile_dirs[@]} ]; then
            echo -e "${RED}Invalid choice.${NC}"
            return 1
        fi

        PROFILE_PATH="${profile_dirs[$((choice-1))]}"
        PROFILE_NAME="${profile_names[$((choice-1))]}"
    fi

    echo -e "${GREEN}Selected profile:${NC} $PROFILE_PATH"
    return 0
}

# Function to install fx-autoconfig
install_fx_autoconfig() {
    echo -e "\n${BLUE}Installing fx-autoconfig...${NC}"

    # Create a temporary directory for the clone
    local temp_dir=$(mktemp -d)

    echo -e "${YELLOW}Downloading fx-autoconfig...${NC}"
    if ! git clone https://github.com/MrOtherGuy/fx-autoconfig "$temp_dir"; then
        echo -e "${RED}Failed to download fx-autoconfig.${NC}"
        rm -rf "$temp_dir"
        return 1
    fi

    echo -e "${GREEN}Download complete!${NC}"

    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    echo -e "${BLUE}Creating backups in:${NC} $BACKUP_DIR"

    # Install program files
    echo -e "${YELLOW}Installing program files to:${NC} $BROWSER_PATH"

    # Back up existing files first
    backup_file "$BROWSER_PATH/config.js"
    backup_file "$BROWSER_PATH/defaults/pref/config-prefs.js"

    # Copy program files
    if [[ "$OS" == "windows" ]]; then
        mkdir -p "$BROWSER_PATH/defaults/pref"
        cp "$temp_dir/program/config.js" "$BROWSER_PATH/"
        cp "$temp_dir/program/defaults/pref/config-prefs.js" "$BROWSER_PATH/defaults/pref/"

        # Set permissions (Windows doesn't need chmod)
    else
        sudo mkdir -p "$BROWSER_PATH/defaults/pref"
        sudo cp "$temp_dir/program/config.js" "$BROWSER_PATH/"
        sudo cp "$temp_dir/program/defaults/pref/config-prefs.js" "$BROWSER_PATH/defaults/pref/"

        # Set permissions
        sudo chmod 644 "$BROWSER_PATH/config.js"
        sudo chmod 644 "$BROWSER_PATH/defaults/pref/config-prefs.js"
    fi

    echo -e "${GREEN}✓ Program files installed!${NC}"

    # Install profile files
    echo -e "${YELLOW}Installing profile files to:${NC} $PROFILE_PATH"

    # Create required directories
    mkdir -p "$PROFILE_PATH/chrome/JS"
    mkdir -p "$PROFILE_PATH/chrome/CSS"
    mkdir -p "$PROFILE_PATH/chrome/resources"
    mkdir -p "$PROFILE_PATH/chrome/utils"

    # Back up existing files
    if [ -d "$PROFILE_PATH/chrome/utils" ]; then
        for file in "$PROFILE_PATH/chrome/utils"/*; do
            if [ -f "$file" ]; then
                backup_file "$file"
            fi
        done
    fi

    # Copy profile files
    cp "$temp_dir/profile/chrome/utils/boot.sys.mjs" "$PROFILE_PATH/chrome/utils/"
    cp "$temp_dir/profile/chrome/utils/chrome.manifest" "$PROFILE_PATH/chrome/utils/"
    cp "$temp_dir/profile/chrome/utils/fs.sys.mjs" "$PROFILE_PATH/chrome/utils/"
    cp "$temp_dir/profile/chrome/utils/utils.sys.mjs" "$PROFILE_PATH/chrome/utils/"

    # Copy the newer API file if it exists
    if [ -f "$temp_dir/profile/chrome/utils/uc_api.sys.mjs" ]; then
        cp "$temp_dir/profile/chrome/utils/uc_api.sys.mjs" "$PROFILE_PATH/chrome/utils/"
    fi

    # Copy module_loader.mjs
    if [ -f "$temp_dir/profile/chrome/utils/module_loader.mjs" ]; then
        cp "$temp_dir/profile/chrome/utils/module_loader.mjs" "$PROFILE_PATH/chrome/utils/"
    fi


    # Set permissions - skip for Windows as it doesn't use chmod
    if [[ "$OS" != "windows" ]]; then
        chmod -R 755 "$PROFILE_PATH/chrome"
        chmod 644 "$PROFILE_PATH/chrome/utils"/*.mjs
        chmod 644 "$PROFILE_PATH/chrome/utils/chrome.manifest"
    fi

    # Create a test script
    echo -e "${YELLOW}Creating a test script...${NC}"
    cat > "$PROFILE_PATH/chrome/JS/test.uc.js" << 'EOF'
// ==UserScript==
// @name           Test Script
// @description    Test if userChrome.js manager is working
// @include        main
// @ignorecache
// ==/UserScript==

(function() {
  console.log("USERCHROME.JS TEST - MANAGER WORKING!");

  // Try to add a visible element to the browser UI
  try {
    // Wait for the browser window to fully initialize
    setTimeout(() => {
      let document = window.document;

      // Create a notification bar
      if (document.getElementById("browser") && document.createXULElement) {
        let notification = document.createXULElement("hbox");
        notification.setAttribute("style", "background-color: green; color: white; padding: 5px; font-weight: bold; text-align: center;");
        notification.textContent = "userChrome.js manager is working!";

        // Try to insert into the browser
        let browserBox = document.getElementById("browser");
        if (browserBox && browserBox.parentNode) {
          browserBox.parentNode.insertBefore(notification, browserBox);
        }
      }
    }, 3000); // 3 second delay to ensure browser is loaded
  } catch (e) {
    console.error("Failed to create notification:", e);
  }
})();
EOF

    # Set permissions for the test script - skip for Windows
    if [[ "$OS" != "windows" ]]; then
        chmod 644 "$PROFILE_PATH/chrome/JS/test.uc.js"
    fi
    echo -e "${GREEN}✓ Test script created!${NC}"

    # Clear startup cache
    echo -e "${YELLOW}Clearing startup cache...${NC}"
    rm -rf "$PROFILE_PATH/startupCache" 2>/dev/null
    rm -rf "$PROFILE_PATH/cache2" 2>/dev/null
    echo -e "${GREEN}✓ Startup cache cleared!${NC}"

    # Clean up
    rm -rf "$temp_dir"

    echo -e "\n${GREEN}=====================================${NC}"
    echo -e "${GREEN}   fx-autoconfig Installation Complete!${NC}"
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${YELLOW}Browser:${NC} $BROWSER_NAME at $BROWSER_PATH"
    echo -e "${YELLOW}Profile:${NC} $PROFILE_PATH"
    echo -e "${YELLOW}Backups:${NC} $BACKUP_DIR"

    # Show different instructions based on OS
    if [[ "$OS" == "windows" ]]; then
        echo -e "\n${CYAN}To test if the installation works, follow these steps:${NC}"
        echo -e "  ${CYAN}1. Launch your browser${NC}"
        echo -e "  ${CYAN}2. Press F12 or Ctrl+Shift+J to open the Browser Console${NC}"
        echo -e "  ${CYAN}3. Look for 'USERCHROME.JS TEST - MANAGER WORKING!' in the console${NC}"
        echo -e "  ${CYAN}4. You should also see a green bar at the top of the browser window${NC}"
        echo -e "\n${CYAN}If you don't see these indicators, try:${NC}"
        echo -e "  ${CYAN}1. Go to about:support in the address bar${NC}"
        echo -e "  ${CYAN}2. Find the 'Clear Startup Cache...' button in the top right${NC}"
        echo -e "  ${CYAN}3. Click it and let the browser restart${NC}"
    else
        echo -e "\n${CYAN}To test if the installation works, follow these steps:${NC}"
        echo -e "  ${CYAN}1. Launch your browser${NC}"
        echo -e "  ${CYAN}2. Press Ctrl+Shift+J to open the Browser Console${NC}"
        echo -e "  ${CYAN}3. Look for 'USERCHROME.JS TEST - MANAGER WORKING!' in the console${NC}"
        echo -e "  ${CYAN}4. You should also see a green bar at the top of the browser window${NC}"
        echo -e "\n${CYAN}If you don't see these indicators, try:${NC}"
        echo -e "  ${CYAN}1. Go to about:support in the address bar${NC}"
        echo -e "  ${CYAN}2. Find the 'Clear Startup Cache...' button in the top right${NC}"
        echo -e "  ${CYAN}3. Click it and let the browser restart${NC}"
    fi

    return 0
}

# Function to install Sine
install_sine() {
    echo -e "\n${BLUE}Installing Sine...${NC}"
    
    # Check if fx-autoconfig is already installed
    if [ ! -d "$PROFILE_PATH/chrome/utils" ] || [ ! -f "$PROFILE_PATH/chrome/utils/boot.sys.mjs" ]; then
        echo -e "${YELLOW}fx-autoconfig doesn't appear to be installed. Installing it first...${NC}"
        install_fx_autoconfig
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to install fx-autoconfig, which is required for Sine.${NC}"
            return 1
        fi
    fi
    
    # Create a temporary directory for the clone
    local temp_dir=$(mktemp -d)
    
    echo -e "${YELLOW}Downloading Sine...${NC}"
    if ! git clone https://github.com/CosmoCreeper/Sine "$temp_dir"; then
        echo -e "${RED}Failed to download Sine.${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    echo -e "${GREEN}Download complete!${NC}"
    
    # Check if sine.uc.mjs exists in the repo
    if [ ! -f "$temp_dir/sine.uc.mjs" ]; then
        echo -e "${RED}Could not find sine.uc.mjs in the downloaded repository.${NC}"
        echo -e "${YELLOW}Checking alternative locations...${NC}"
        
        # Try to find it elsewhere in the repo
        local sine_file=$(find "$temp_dir" -name "sine.uc.mjs" | head -n 1)
        
        if [ -z "$sine_file" ]; then
            echo -e "${RED}Could not find sine.uc.mjs anywhere in the repository.${NC}"
            rm -rf "$temp_dir"
            return 1
        else
            echo -e "${GREEN}Found sine.uc.mjs at:${NC} $sine_file"
        fi
    else
        sine_file="$temp_dir/sine.uc.mjs"
    fi
    
    # Create JS directory if it doesn't exist
    mkdir -p "$PROFILE_PATH/chrome/JS"
    
    # Backup existing sine file if it exists
    if [ -f "$PROFILE_PATH/chrome/JS/sine.uc.mjs" ]; then
        backup_file "$PROFILE_PATH/chrome/JS/sine.uc.mjs"
    fi
    
    # Copy sine.uc.mjs to the profile's JS directory
    cp "$sine_file" "$PROFILE_PATH/chrome/JS/"
    
    echo -e "${GREEN}✓ Sine has been installed to:${NC} $PROFILE_PATH/chrome/JS/sine.uc.mjs"
    
    # Set permissions for the Sine script - skip for Windows
    if [[ "$OS" != "windows" ]]; then
        chmod 644 "$PROFILE_PATH/chrome/JS/sine.uc.mjs"
    fi
    
    # Clear startup cache
    echo -e "${YELLOW}Clearing startup cache...${NC}"
    rm -rf "$PROFILE_PATH/startupCache" 2>/dev/null
    rm -rf "$PROFILE_PATH/cache2" 2>/dev/null
    echo -e "${GREEN}✓ Startup cache cleared!${NC}"
    
    # Clean up
    rm -rf "$temp_dir"
    
    echo -e "\n${GREEN}=====================================${NC}"
    echo -e "${GREEN}         Sine Installation Complete!${NC}"
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${YELLOW}Browser:${NC} $BROWSER_NAME"
    echo -e "${YELLOW}Profile:${NC} $PROFILE_PATH"
    echo -e "${YELLOW}Sine installed to:${NC} $PROFILE_PATH/chrome/JS/sine.uc.mjs"
    
    # Show different instructions based on OS
    echo -e "\n${CYAN}To start using Sine, follow these steps:${NC}"
    echo -e "  ${CYAN}1. Launch your browser${NC}"
    echo -e "  ${CYAN}2. Clear the startup cache by going to about:support and clicking 'Clear Startup Cache...'${NC}"
    echo -e "  ${CYAN}3. When the browser restarts, Sine should be active${NC}"
    echo -e "  ${CYAN}4. You can find Sine features in the browser settings or through its marketplace${NC}"
    
    return 0
}

# Main function
main() {
    print_header
    detect_os

    echo -e "${YELLOW}What would you like to do?${NC}"
    echo -e "${CYAN}1)${NC} Install fx-autoconfig"
    echo -e "${CYAN}2)${NC} Install Sine (includes fx-autoconfig if needed)"
    echo -e "${CYAN}3)${NC} Restore from backup"
    echo -e "${CYAN}q)${NC} Quit"

    read -r action

    case "$action" in
        1)
            if detect_browsers && detect_profiles; then
                install_fx_autoconfig
            else
                echo -e "${RED}Installation failed.${NC}"
                exit 1
            fi
            ;;
        2)
            if detect_browsers && detect_profiles; then
                install_sine
            else
                echo -e "${RED}Installation failed.${NC}"
                exit 1
            fi
            ;;
        3)
            restore_backup
            ;;
        q|Q)
            echo -e "${YELLOW}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice.${NC}"
            exit 1
            ;;
    esac
}

# Run the main function
main