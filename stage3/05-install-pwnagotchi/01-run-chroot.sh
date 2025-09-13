#!/bin/bash -e

cd /home/pi

echo -e "\e[32m### Manually installing lgpio from source ###\e[0m"
wget http://abyz.me.uk/lg/lg.zip
unzip lg.zip
cd lg
make
make install

cd /home/pi
rm -rf lg.zip lg/

# Check if pwnagotchi directory was copied by 00-run.sh
if [ ! -d "pwnagotchi" ]; then
    echo "Error: pwnagotchi directory not found. It should have been copied by 00-run.sh"
    exit 1
fi

echo "Found pwnagotchi directory, contents:"
ls -la pwnagotchi/

# Check if we have a setup.py file, if not, we need to handle installation differently
cd pwnagotchi

# Fix the locale module conflict by temporarily renaming the locale directory
if [ -d "locale" ]; then
    echo "Temporarily renaming locale directory to avoid Python import conflict..."
    mv locale locale_data
    LOCALE_RENAMED=1
else
    LOCALE_RENAMED=0
fi

if [ ! -f "setup.py" ] && [ ! -f "pyproject.toml" ]; then
    echo "No setup.py or pyproject.toml found, creating a simple setup.py for pwnagotchi installation..."
    cat > setup.py << 'EOF'
#!/usr/bin/env python3

from setuptools import setup, find_packages
import os

# Read version from _version.py
version = {}
with open("_version.py") as fp:
    exec(fp.read(), version)

# Find packages but exclude the locale_data directory if it exists
packages = find_packages()
if 'locale_data' in packages:
    packages.remove('locale_data')

setup(
    name="pwnagotchi",
    version=version['__version__'],
    description="Deep Reinforcement Learning instrumenting bettercap for WiFi pwning.",
    author="Simone Margaritelli",
    author_email="evilsocket@gmail.com",
    url="https://pwnagotchi.ai/",
    packages=packages,
    include_package_data=True,
    package_data={
        'pwnagotchi': ['locale_data/**/*', 'defaults.toml'],
    },
    install_requires=[
        "cryptography",
        "flask",
        "flask-cors",
        "flask-wtf",
        "pillow",
        "requests",
        "scapy",
        "numpy",
        "psutil",
        "dbus-python",
        "gpiozero",
    ],
    entry_points={
        'console_scripts': [
            'pwnagotchi=pwnagotchi.cli:main',
        ],
    },
    python_requires='>=3.7',
)
EOF
    echo "Created setup.py file for pwnagotchi"
fi

if [ -d /home/pi/.pwn ]; then
    rm -rf /home/pi/.pwn
fi

if [ "$(uname -m)" = "armv6l" ]; then
    export QEMU_CPU=arm1176
fi

echo -e "\e[32m### Installing python virtual environment ###\e[0m"
# Change to a different directory to avoid import conflicts during venv creation
cd /tmp
python3 -m venv /home/pi/.pwn/ --system-site-packages

echo -e "\e[32m### Activating virtual environment ###\e[0m"
source /home/pi/.pwn/bin/activate

# Go back to pwnagotchi directory
cd /home/pi/pwnagotchi

echo -e "\e[32m### Configuring pip for better reliability ###\e[0m"
# Configure pip to handle SSL issues and use multiple index URLs
pip3 config set global.trusted-host "pypi.org files.pythonhosted.org pypi.python.org archive1.piwheels.org"
pip3 config set global.timeout 60
pip3 config set global.retries 3

# Set multiple index URLs as fallbacks
pip3 config set global.index-url "https://pypi.org/simple/"
pip3 config set global.extra-index-url "https://archive1.piwheels.org/simple/ https://files.pythonhosted.org/simple/"

echo -e "\e[32m### Installing pwnagotchi requirements ###\e[0m"
pip3 install --upgrade pip

# Install packages with better error handling
install_package() {
    local package=$1
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        echo "Installing $package (attempt $attempt/$max_attempts)..."
        if pip3 install --no-cache-dir "$package"; then
            echo "Successfully installed $package"
            return 0
        else
            echo "Failed to install $package on attempt $attempt"
            if [ $attempt -lt $max_attempts ]; then
                echo "Retrying in 5 seconds..."
                sleep 5
            fi
            attempt=$((attempt + 1))
        fi
    done

    echo "Warning: Failed to install $package after $max_attempts attempts"
    return 1
}

# Install core packages first
install_package "wheel"
install_package "setuptools"

# Install essential packages for pwnagotchi
echo "Installing essential packages for pwnagotchi..."
for pkg in "cryptography" "flask" "flask-cors" "flask-wtf" "pillow" "requests" "scapy" "numpy" "psutil" "dbus-python"; do
    install_package "$pkg" || echo "Continuing despite failure to install $pkg"
done

echo -e "\e[32m### Installing pwnagotchi package ###\e[0m"
# Install pwnagotchi in development mode
if pip3 install -e .; then
    echo "Successfully installed pwnagotchi in development mode"
elif python3 setup.py develop; then
    echo "Successfully installed pwnagotchi using setup.py develop"
else
    echo "Warning: Failed to install pwnagotchi package, but continuing..."
    # Manual installation as last resort
    echo "Attempting manual installation..."
    python3 setup.py build
    python3 setup.py install
fi

# Restore the locale directory name after installation
if [ $LOCALE_RENAMED -eq 1 ]; then
    echo "Restoring locale directory name..."
    mv locale_data locale
fi

echo -e "\e[32m### Setting up pwnagotchi user permissions ###\e[0m"
chown -R pi:pi /home/pi/pwnagotchi
chown -R pi:pi /home/pi/.pwn

# Verify installation
echo -e "\e[32m### Verifying pwnagotchi installation ###\e[0m"
cd /tmp  # Change directory to avoid import conflicts during verification
if python3 -c "import pwnagotchi; print('Pwnagotchi module imported successfully')"; then
    echo "Pwnagotchi installation verified successfully"
else
    echo "Warning: Pwnagotchi module import failed, but continuing with build"
fi

echo -e "\e[32m### Pwnagotchi installation completed ###\e[0m"
