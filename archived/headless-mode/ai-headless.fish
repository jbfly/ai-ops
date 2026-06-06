function ai-headless
    echo "ai-headless is deprecated. The desktop can stay up now."
    echo "Starting the compatibility headless service without touching the GUI stack..."
    systemctl --user stop llama-server-desktop.service 2>/dev/null
    systemctl --user start llama-server-headless.service
    ai-status
end
