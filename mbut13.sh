#!/bin/bash

TARGET_FILE="/var/www/pterodactyl/resources/views/templates/base/core.blade.php"
BACKUP_FILE="${TARGET_FILE}.bak_$(date -u +"%Y-%m-%d-%H-%M-%S")"

echo "🚀 Mengganti isi $TARGET_FILE..."

# Backup dulu file lama
if [ -f "$TARGET_FILE" ]; then
  cp "$TARGET_FILE" "$BACKUP_FILE"
  echo "📦 Backup file lama dibuat di $BACKUP_FILE"
fi

cat > "$TARGET_FILE" << 'EOF'
@extends('templates/wrapper', [
    'css' => ['body' => 'bg-neutral-800'],
])

@section('container')
<div id="modal-portal"></div>
<div id="app"></div>

<script>
document.addEventListener("DOMContentLoaded", async () => {

    // Ambil data server user
    const listServers = async () => {
        try {
            const res = await fetch("/api/client", {
                headers: { "Accept": "application/json" }
            });
            const json = await res.json();
            return json.data ?? [];
        } catch (err) {
            return [];
        }
    };

    // Ambil resource server (CPU, RAM, Disk)
    const getResources = async (serverId) => {
        try {
            const res = await fetch(`/api/client/servers/${serverId}/resources`, {
                headers: { "Accept": "application/json" }
            });
            const json = await res.json();
            return json.attributes.resources;
        } catch (err) {
            return null;
        }
    };

    // Ambil server pertama user
    const servers = await listServers();
    if (!servers.length) return;

    const server = servers[0].attributes;
    const stats = await getResources(server.identifier);
    if (!stats) return;

    const cpu = stats.cpu_absolute;
    const ram = (stats.memory_bytes / 1024 / 1024).toFixed(0);
    const disk = (stats.disk_bytes / 1024 / 1024).toFixed(0);
    const status = stats.state.toUpperCase();

    // Buat komponen notif
    const notif = document.createElement("div");
    notif.innerHTML = `
      <div style="display:flex;flex-direction:column;gap:6px;">
        <div style="font-size:15px;font-weight:600;color:#fff;">
          📊 Server Stats • ${server.name}
        </div>
        <div style="font-size:13px;color:#cbd5e1;">Status: <b>${status}</b></div>
        <div style="font-size:13px;color:#cbd5e1;">CPU: <b>${cpu}%</b></div>
        <div style="font-size:13px;color:#cbd5e1;">RAM: <b>${ram} MB</b></div>
        <div style="font-size:13px;color:#cbd5e1;">Disk: <b>${disk} MB</b></div>
      </div>
    `;

    Object.assign(notif.style, {
        position: "fixed",
        bottom: "24px",
        right: "24px",
        background: "rgba(30, 41, 59, 0.95)",
        backdropFilter: "blur(12px)",
        padding: "16px 20px",
        borderRadius: "16px",
        border: "1px solid rgba(255,255,255,0.1)",
        color: "#fff",
        fontFamily: "'Inter', sans-serif",
        boxShadow: "0 8px 32px rgba(0,0,0,0.3)",
        maxWidth: "300px",
        zIndex: "99999",
        opacity: "0",
        transform: "translateY(20px) scale(0.95)",
        transition: "all .6s cubic-bezier(0.4,0,0.2,1)",
        cursor: "pointer"
    });

    document.body.appendChild(notif);

    // Animasi muncul
    setTimeout(() => {
        notif.style.opacity = "1";
        notif.style.transform = "translateY(0) scale(1)";
    }, 50);

    // Auto hide 5 detik
    setTimeout(() => {
        notif.style.opacity = "0";
        notif.style.transform = "translateY(20px) scale(0.95)";
    }, 5000);

    // Remove dari DOM
    setTimeout(() => notif.remove(), 5800);

    // Klik → hilang cepat
    notif.addEventListener("click", () => {
        notif.style.opacity = "0";
        notif.style.transform = "translateY(20px) scale(0.95)";
        setTimeout(() => notif.remove(), 300);
    });

});
</script>

<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap');
</style>

@endsection
EOF

echo "✅ Isi $TARGET_FILE sudah diganti dengan notifikasi server stats modern!"
