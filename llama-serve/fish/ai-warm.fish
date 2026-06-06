function ai-warm
    ~/.config/llama-serve/gpu-mode auto >/dev/null 2>/dev/null
    ~/.config/llama-serve/gpu-mode warm
    ai-status
end
