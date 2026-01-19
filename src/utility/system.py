import subprocess
import os

def is_wayland() -> bool:
    """
    Check if we are in a Wayland environment

    Returns:
        bool: True if we are in a Wayland environment
    """
    if os.getenv("WAYLAND_DISPLAY"):
        return True
    return False

def is_appimage() -> bool:
    """
    Check if we are in an appimage

    Returns:
        bool: True if we are in an appimage
    """
    if os.getenv('APPIMAGE') or os.getenv('APPDIR'):
        return True
    return False

def is_flatpak() -> bool:
    """
    Check if we are in a flatpak

    Returns:
        bool: True if we are in a flatpak
    """
    if os.path.exists('/.flatpak-info') or os.getenv('FLATPAK_ID'):
        return True
    return False

def is_snap() -> bool:
    """
    Check if we are in a snap package

    Returns:
        bool: True if we are in a snap package
    """
    if os.getenv('SNAP'):
        return True
    return False

def can_escape_sandbox() -> bool:
    """
    Check if we can escape the sandbox

    Returns:
        bool: True if we can escape the sandbox
    """
    if is_flatpak():
        try:
            r = subprocess.check_output(["flatpak-spawn", "--host", "echo", "test"])
        except subprocess.CalledProcessError as _:
            return False
        return True
    if is_snap():
        if not os.path.exists("/etc/shells"):
            print("no --classic tag enabled, can't execute command outside")
            return False
    return True

def get_spawn_command() -> list:
    """
    Get the spawn command to run commands on the user system

    Returns:
        list: space diveded command
    """
    if is_flatpak():
        return ["flatpak-spawn", "--host"]
    else:
        return []

def open_website(website):
    """Opens a website using xdg-open

    Args:
        website (): url of the website
    """
    subprocess.Popen(get_spawn_command() + ["xdg-open", website])

def open_folder(folder):
    """Opens a website using xdg-open

    Args:
        folder (): location of the folder
    """
    subprocess.Popen(get_spawn_command() + ["xdg-open", folder])

