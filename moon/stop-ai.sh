#!/bin/bash

# 1. Restart the GUI on Alpha
echo "🖥️ Restoring Plasma Desktop on Alpha..."
ssh jbfly@alpha "sudo systemctl start plasmalogin"

echo "✅ Desktop restored. Alpha is back to normal."

