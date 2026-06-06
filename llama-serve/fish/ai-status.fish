function ai-status
    set -l active "~/.config/llama-serve/active.env"
    if test -L ~/.config/llama-serve/active.env
        set active (readlink ~/.config/llama-serve/active.env)
    else if test -f ~/.config/llama-serve/active.env
        set active ~/.config/llama-serve/active.env
    else
        set active "missing"
    end

    echo "active model env: $active"
    echo "proxy service: "(systemctl --user is-active llama-proxy.service 2>/dev/null)
    echo "backend service: "(systemctl --user is-active llama-server.service 2>/dev/null)
    echo "idle timer: "(systemctl --user is-active llama-idle-stop.timer 2>/dev/null)
    echo "audiomuse watch timer: "(systemctl --user is-active audiomuse-gpu-watch.timer 2>/dev/null)

    if command -sq curl
        set -l proxy_status (curl -fsS http://127.0.0.1:8090/admin/status 2>/dev/null)
        if test -n "$proxy_status"
            echo "proxy status: $proxy_status"
        else
            echo "proxy not reachable"
        end
    end

    if command -sq nvidia-smi
        nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader,nounits | while read -l line
            set -l used (string split ',' $line)[1]
            set -l free (string split ',' $line)[2]
            echo "gpu memory used/free MiB: "(string trim $used)" / "(string trim $free)
        end
    else
        echo "nvidia-smi not found"
    end
end
