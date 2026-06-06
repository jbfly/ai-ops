function ai-stop
    systemctl --user stop llama-server.service llama-server-desktop.service llama-server-headless.service 2>/dev/null
    echo "llama backend stopped; proxy stays up"
end
