#!/bin/bash -e

echo -e "\e[32m### Configuring pwnagotchi touch interface ###\e[0m"

# Create the pwnagotchi systemd service file
echo "Creating pwnagotchi systemd service..."
cat > /etc/systemd/system/pwnagotchi.service << 'EOF'
[Unit]
Description=Pwnagotchi AI
Documentation=https://pwnagotchi.ai
Wants=network.target
After=network.target

[Service]
Type=simple
User=pi
Group=pi
UMask=0002
WorkingDirectory=/home/pi
Environment=DISPLAY=:0.0
ExecStart=/home/pi/.pwn/bin/python -m pwnagotchi
ExecReload=/bin/kill -USR1 $MAINPID
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Create the pwnagotchi-touch service (if this is the touch version)
echo "Creating pwnagotchi-touch systemd service..."
cat > /etc/systemd/system/pwnagotchi-touch.service << 'EOF'
[Unit]
Description=Pwnagotchi Touch Interface
Documentation=https://pwnagotchi.ai
After=pwnagotchi.service
Requires=pwnagotchi.service

[Service]
Type=simple
User=pi
Group=pi
UMask=0002
WorkingDirectory=/home/pi
Environment=DISPLAY=:0.0
ExecStart=/home/pi/.pwn/bin/python -m pwnagotchi --touch
ExecReload=/bin/kill -USR1 $MAINPID
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Set proper permissions on service files
chmod 644 /etc/systemd/system/pwnagotchi.service
chmod 644 /etc/systemd/system/pwnagotchi-touch.service

# Reload systemd to recognize new services
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable the services (but don't start them during build)
echo "Enabling pwnagotchi services..."
systemctl enable pwnagotchi.service || echo "Warning: Failed to enable pwnagotchi.service"

if systemctl enable pwnagotchi-touch.service; then
    echo "Successfully enabled pwnagotchi-touch.service"
else
    echo "Warning: Failed to enable pwnagotchi-touch.service, but continuing..."
fi

# Create pwnagotchi configuration directory if it doesn't exist
mkdir -p /etc/pwnagotchi

# Copy the interactive config if it exists
if [ -f "/tmp/config_interactive.toml" ]; then
    echo "Installing interactive configuration..."
    cp /tmp/config_interactive.toml /etc/pwnagotchi/config.toml
    chown pi:pi /etc/pwnagotchi/config.toml
    chmod 644 /etc/pwnagotchi/config.toml
elif [ -f "/home/pi/pwnagotchi/defaults.toml" ]; then
    echo "Installing default configuration..."
    cp /home/pi/pwnagotchi/defaults.toml /etc/pwnagotchi/config.toml
    chown pi:pi /etc/pwnagotchi/config.toml
    chmod 644 /etc/pwnagotchi/config.toml
else
    echo "Warning: No configuration file found, creating minimal config..."
    cat > /etc/pwnagotchi/config.toml << 'EOF'
main.name = "pwnagotchi"
main.lang = "en"
main.whitelist = []
main.plugins_dir = "/usr/local/share/pwnagotchi/custom-plugins/"

ui.display.enabled = true
ui.display.type = "waveshare_2"

personality.advertise = true
personality.deauth = true
personality.associate = true
EOF
    chown pi:pi /etc/pwnagotchi/config.toml
    chmod 644 /etc/pwnagotchi/config.toml
fi

# Set up proper permissions for pwnagotchi directories
echo "Setting up pwnagotchi permissions..."
chown -R pi:pi /etc/pwnagotchi
chown -R pi:pi /usr/local/share/pwnagotchi
chown -R pi:pi /home/pi/pwnagotchi
chown -R pi:pi /home/pi/.pwn

# Create log directory
mkdir -p /var/log/pwnagotchi
chown pi:pi /var/log/pwnagotchi

echo -e "\e[32m### Pwnagotchi touch interface configuration completed ###\e[0m"
