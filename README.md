# fx-autoconfig Automatic Installer (autoconfig-auto.sh)

## Overview

This script provides an easy way to install the fx-autoconfig system on Firefox-based browsers, including:
- Firefox
- Firefox ESR
- Zen Browser
- Zen Twilight
- LibreWolf
- Waterfox
- And other Firefox derivatives

fx-autoconfig lets you run custom JavaScript in your browser, allowing for extensive customization beyond what's possible with just CSS.

## Features

- **Interactive Installation**: Simple menu-driven interface
- **Auto-detection**: Automatically finds Firefox-based browsers and profiles
- **Profile Selection**: Choose which profile to install to
- **Multiple Browser Support**: Works with a wide variety of Firefox derivatives
- **Backup System**: Creates automatic backups before making any changes
- **Restore Function**: Easily restore from previous backups
- **Test Verification**: Includes a visual test to confirm successful installation

## Requirements

- Git (to download the fx-autoconfig repository)
- Bash shell
- sudo privileges (to install files to system directories)

## Usage

1. Make the script executable:
   ```
   chmod +x autoconfig-auto.sh
   ```

2. Run the script:
   ```
   ./autoconfig-auto.sh
   ```

3. Follow the interactive prompts to:
   - Choose between installation or restoration
   - Select your browser installation
   - Select your profile

4. After installation, restart your browser and:
   - Press Ctrl+Shift+J to open the Browser Console
   - Look for a "USERCHROME.JS TEST - MANAGER WORKING!" message
   - Note the green bar at the top of your browser window

If you don't see these indicators, go to `about:support` in your address bar and click "Clear Startup Cache..." in the top-right corner.

## Using fx-autoconfig

After installation:

1. Custom scripts go in: `[profile-dir]/chrome/JS/`
   - Use `.uc.js` extension for standard scripts
   - Use `.uc.mjs` extension for ES6 module scripts
   - Use `.sys.mjs` extension for background scripts

2. Custom styles go in: `[profile-dir]/chrome/CSS/`
   - Use `.uc.css` extension

3. Resources (images, etc.) go in: `[profile-dir]/chrome/resources/`

4. Manage your scripts and styles from the "User Scripts" menu in your browser's Tools menu.

## Backup & Restoration

The script automatically creates backups in `~/.fx-autoconfig-backups/[timestamp]/` before making changes.

To restore from a backup:
1. Run the script
2. Select option 2 (Restore from backup)
3. Choose which backup to restore from

## Common Issues

- **Script Not Working**: Clear the startup cache via `about:support`
- **Can't Find Browser**: Use manual entry mode and specify the directory path
- **Can't Find Profile**: Use manual entry mode and specify your profile path
- **Permission Denied**: Make sure you have the necessary permissions for the directories

## Credits

This installer script was created to simplify the installation of fx-autoconfig, which was developed by MrOtherGuy.

- Original fx-autoconfig repository: https://github.com/MrOtherGuy/fx-autoconfig

## Safety Note

The fx-autoconfig system allows arbitrary JavaScript to run with browser privileges. Only install scripts from sources you trust.

## License

This installer script is provided under the same license as fx-autoconfig (MIT License).
