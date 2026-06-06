function ai-model
    set -l models_dir ~/.config/llama-serve/models

    if test (count $argv) -lt 1
        echo "usage: ai-model <name>"
        echo "available models:"
        for f in $models_dir/*.env
            if test -e $f
                echo "  "(basename $f .env)
            end
        end
        return 1
    end

    set -l name $argv[1]
    set -l target "$models_dir/$name.env"

    if not test -f $target
        echo "model not found: $name"
        echo "available models:"
        for f in $models_dir/*.env
            if test -e $f
                echo "  "(basename $f .env)
            end
        end
        return 1
    end

    ln -sfn $target ~/.config/llama-serve/active.env
    echo "switched active model to: $name"

    if systemctl --user is-active --quiet llama-server.service
        systemctl --user restart llama-server.service
        echo "restarted llama-server.service"
    else
        echo "llama-server is not active; model switch will apply on next start"
    end
end
