function ai-desktop
    systemctl --user start llama-proxy.service
    ~/.config/llama-serve/gpu-mode auto >/dev/null 2>/dev/null
    ~/.config/llama-serve/gpu-mode warm >/dev/null
    ai-status
end
