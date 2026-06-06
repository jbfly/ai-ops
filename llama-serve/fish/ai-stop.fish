function ai-stop
    systemctl --user stop llama-server.service 2>/dev/null
    echo "llama backend stopped; proxy stays up"
end
