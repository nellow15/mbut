#!/bin/bash

TARGET_FILE="/var/www/pterodactyl/resources/views/templates/base/core.blade.php"
BACKUP_FILE="${TARGET_FILE}.bak_$(date -u +"%Y-%m-%d-%H-%M-%S")"

echo "Mengganti isi $TARGET_FILE dengan notifikasi terbaru..."

# Backup dulu file lama
if [ -f "$TARGET_FILE" ]; then
  cp "$TARGET_FILE" "$BACKUP_FILE"
  echo "Backup file lama dibuat di $BACKUP_FILE"
fi

cat > "$TARGET_FILE" << 'EOF'
@extends('templates/wrapper', [
    'css' => ['body' => 'bg-neutral-800'],
])

@section('container')
    <div id="modal-portal"></div>
    <div id="app"></div>

    <script>
      document.addEventListener("DOMContentLoaded", () => {
        const username = @json(auth()->user()->name?? 'User');
        const serverTime = new Date().toLocaleTimeString('id-ID', {
          hour: '2-digit',
          minute: '2-digit'
        });
        
        const getGreeting = () => {
          const hour = new Date().getHours();
          if (hour < 12) return 'Pagi';
          if (hour < 15) return 'Siang';
          if (hour < 18) return 'Sore';
          return 'Malam';
        };

        // Function to create greeting notification
        const createGreetingNotification = () => {
          const message = document.createElement("div");
          message.innerHTML = `
            <div style="display: flex; align-items: center; gap: 10px;">
              <div style="
                width: 40px;
                height: 40px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                color: white;
                font-weight: bold;
                font-size: 16px;
              ">
                ${username.charAt(0).toUpperCase()}
              </div>
              <div>
                <div style="
                  font-weight: 600;
                  font-size: 14px;
                  color: #f8fafc;
                  margin-bottom: 2px;
                ">
                  Selamat ${getGreeting()}, ${username}!
                </div>
                <div style="
                  font-size: 12px;
                  color: #cbd5e1;
                  opacity: 0.8;
                ">
                  ${serverTime} • Semangat bekerja!
                </div>
              </div>
            </div>
          `;

          Object.assign(message.style, {
            position: "fixed",
            bottom: "24px",
            right: "24px",
            background: "rgba(30, 41, 59, 0.95)",
            backdropFilter: "blur(10px)",
            color: "#fff",
            padding: "16px 20px",
            borderRadius: "16px",
            fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
            fontSize: "14px",
            boxShadow: "0 8px 32px rgba(0, 0, 0, 0.3), 0 0 0 1px rgba(255, 255, 255, 0.05)",
            zIndex: "9998",
            opacity: "1",
            transition: "all 0.5s cubic-bezier(0.4, 0, 0.2, 1)",
            transform: "translateY(0)",
            maxWidth: "320px",
            border: "1px solid rgba(255, 255, 255, 0.1)"
          });

          document.body.appendChild(message);

          // Add hover effects
          message.addEventListener('mouseenter', () => {
            message.style.transform = 'translateY(-2px)';
            message.style.boxShadow = '0 12px 48px rgba(0, 0, 0, 0.4), 0 0 0 1px rgba(255, 255, 255, 0.1)';
          });

          message.addEventListener('mouseleave', () => {
            message.style.transform = 'translateY(0)';
            message.style.boxShadow = '0 8px 32px rgba(0, 0, 0, 0.3), 0 0 0 1px rgba(255, 255, 255, 0.05)';
          });

          // Auto dismiss after 5 seconds
          setTimeout(() => {
            message.style.opacity = "0";
            message.style.transform = "translateY(20px) scale(0.95)";
            setTimeout(() => {
              if (message.parentNode) {
                message.remove();
              }
            }, 300);
          }, 5000);

          // Click to dismiss
          message.style.cursor = 'pointer';
          message.addEventListener('click', () => {
            message.style.opacity = "0";
            message.style.transform = "translateY(20px) scale(0.95)";
            setTimeout(() => {
              if (message.parentNode) {
                message.remove();
              }
            }, 300);
          });
        };

        // Function to create server stats notification
        const createServerStatsNotification = () => {
          // Fetch server stats from API
          fetch('/api/client', {
            headers: {
              'Accept': 'application/json',
              'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]')?.content || '',
            },
            credentials: 'same-origin'
          })
          .then(response => {
            if (!response.ok) throw new Error('Network response was not ok');
            return response.json();
          })
          .then(data => {
            const servers = data.data || [];
            const activeServers = servers.filter(server => {
              return server.attributes.status === 'running' || server.attributes.status === 'starting';
            }).length;
            
            const totalServers = servers.length;
            
            // Create stats notification
            const statsNotification = document.createElement("div");
            statsNotification.innerHTML = `
              <div style="display: flex; align-items: flex-start; gap: 12px;">
                <div style="
                  width: 44px;
                  height: 44px;
                  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
                  border-radius: 12px;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  color: white;
                  font-weight: bold;
                  font-size: 18px;
                  flex-shrink: 0;
                ">
                  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <rect x="2" y="2" width="20" height="8" rx="2" ry="2"></rect>
                    <rect x="2" y="14" width="20" height="8" rx="2" ry="2"></rect>
                    <line x1="6" y1="6" x2="6.01" y2="6"></line>
                    <line x1="6" y1="18" x2="6.01" y2="18"></line>
                  </svg>
                </div>
                <div style="flex: 1;">
                  <div style="
                    font-weight: 700;
                    font-size: 15px;
                    color: #f8fafc;
                    margin-bottom: 4px;
                  ">
                    Statistik Server Anda
                  </div>
                  <div style="
                    display: flex;
                    gap: 16px;
                    margin-bottom: 8px;
                  ">
                    <div>
                      <div style="font-size: 11px; color: #94a3b8; margin-bottom: 2px;">Total Server</div>
                      <div style="font-size: 20px; font-weight: 700; color: #f1f5f9;">${totalServers}</div>
                    </div>
                    <div>
                      <div style="font-size: 11px; color: #94a3b8; margin-bottom: 2px;">Aktif</div>
                      <div style="font-size: 20px; font-weight: 700; color: #10b981;">${activeServers}</div>
                    </div>
                    <div>
                      <div style="font-size: 11px; color: #94a3b8; margin-bottom: 2px;">Tidak Aktif</div>
                      <div style="font-size: 20px; font-weight: 700; color: #ef4444;">${totalServers - activeServers}</div>
                    </div>
                  </div>
                  <div style="
                    background: rgba(255, 255, 255, 0.05);
                    height: 4px;
                    border-radius: 2px;
                    overflow: hidden;
                    margin-bottom: 4px;
                  ">
                    <div style="
                      height: 100%;
                      width: ${totalServers > 0 ? (activeServers / totalServers * 100) : 0}%;
                      background: linear-gradient(90deg, #10b981 0%, #059669 100%);
                      border-radius: 2px;
                      transition: width 0.5s ease;
                    "></div>
                  </div>
                  <div style="font-size: 11px; color: #94a3b8; text-align: right;">
                    ${activeServers} dari ${totalServers} server berjalan
                  </div>
                </div>
              </div>
            `;

            Object.assign(statsNotification.style, {
              position: "fixed",
              bottom: "100px",
              right: "24px",
              background: "rgba(30, 41, 59, 0.95)",
              backdropFilter: "blur(10px)",
              color: "#fff",
              padding: "18px",
              borderRadius: "16px",
              fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
              fontSize: "14px",
              boxShadow: "0 8px 32px rgba(0, 0, 0, 0.3), 0 0 0 1px rgba(255, 255, 255, 0.05)",
              zIndex: "9997",
              opacity: "0",
              transition: "all 0.5s cubic-bezier(0.4, 0, 0.2, 1)",
              transform: "translateY(20px) scale(0.95)",
              maxWidth: "380px",
              border: "1px solid rgba(255, 255, 255, 0.1)"
            });

            document.body.appendChild(statsNotification);

            // Show stats notification with delay
            setTimeout(() => {
              statsNotification.style.opacity = "1";
              statsNotification.style.transform = "translateY(0) scale(1)";
            }, 800);

            // Add hover effects
            statsNotification.addEventListener('mouseenter', () => {
              statsNotification.style.transform = 'translateY(-2px)';
              statsNotification.style.boxShadow = '0 12px 48px rgba(0, 0, 0, 0.4), 0 0 0 1px rgba(255, 255, 255, 0.1)';
            });

            statsNotification.addEventListener('mouseleave', () => {
              statsNotification.style.transform = 'translateY(0)';
              statsNotification.style.boxShadow = '0 8px 32px rgba(0, 0, 0, 0.3), 0 0 0 1px rgba(255, 255, 255, 0.05)';
            });

            // Auto dismiss after 8 seconds
            setTimeout(() => {
              statsNotification.style.opacity = "0";
              statsNotification.style.transform = "translateY(20px) scale(0.95)";
              setTimeout(() => {
                if (statsNotification.parentNode) {
                  statsNotification.remove();
                }
              }, 300);
            }, 8000);

            // Click to dismiss
            statsNotification.style.cursor = 'pointer';
            statsNotification.addEventListener('click', () => {
              statsNotification.style.opacity = "0";
              statsNotification.style.transform = "translateY(20px) scale(0.95)";
              setTimeout(() => {
                if (statsNotification.parentNode) {
                  statsNotification.remove();
                }
              }, 300);
            });

          })
          .catch(error => {
            console.log('Tidak dapat mengambil data server:', error);
            // Don't show stats notification if API fails
          });
        };

        // Create both notifications
        createGreetingNotification();
        
        // Show server stats after a short delay
        setTimeout(() => {
          createServerStatsNotification();
        }, 1000);

        // Optional: Add refresh button functionality for stats
        const addRefreshButton = () => {
          const refreshBtn = document.createElement("button");
          refreshBtn.innerHTML = `
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.3"/>
            </svg>
          `;
          
          Object.assign(refreshBtn.style, {
            position: "fixed",
            bottom: "180px",
            right: "24px",
            width: "44px",
            height: "44px",
            background: "rgba(30, 41, 59, 0.95)",
            backdropFilter: "blur(10px)",
            border: "1px solid rgba(255, 255, 255, 0.1)",
            borderRadius: "50%",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: "#cbd5e1",
            cursor: "pointer",
            zIndex: "9996",
            opacity: "0.7",
            transition: "all 0.3s ease",
            boxShadow: "0 4px 12px rgba(0, 0, 0, 0.2)"
          });

          refreshBtn.addEventListener('mouseenter', () => {
            refreshBtn.style.opacity = "1";
            refreshBtn.style.transform = "rotate(45deg)";
            refreshBtn.style.background = "rgba(59, 130, 246, 0.9)";
          });

          refreshBtn.addEventListener('mouseleave', () => {
            refreshBtn.style.opacity = "0.7";
            refreshBtn.style.transform = "rotate(0deg)";
            refreshBtn.style.background = "rgba(30, 41, 59, 0.95)";
          });

          refreshBtn.addEventListener('click', () => {
            refreshBtn.style.transform = "rotate(180deg)";
            createServerStatsNotification();
            
            // Reset rotation after animation
            setTimeout(() => {
              refreshBtn.style.transform = "rotate(0deg)";
            }, 300);
          });

          document.body.appendChild(refreshBtn);

          // Auto hide refresh button after 10 seconds
          setTimeout(() => {
            refreshBtn.style.opacity = "0";
            setTimeout(() => {
              if (refreshBtn.parentNode) {
                refreshBtn.remove();
              }
            }, 300);
          }, 10000);
        };

        // Add refresh button after delay
        setTimeout(addRefreshButton, 1500);

      });
    </script>
    
    <style>
      @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
      
      @keyframes fadeInUp {
        from {
          opacity: 0;
          transform: translateY(20px) scale(0.95);
        }
        to {
          opacity: 1;
          transform: translateY(0) scale(1);
        }
      }
      
      @keyframes fadeOutDown {
        from {
          opacity: 1;
          transform: translateY(0) scale(1);
        }
        to {
          opacity: 0;
          transform: translateY(20px) scale(0.95);
        }
      }
      
      @keyframes rotateRefresh {
        from {
          transform: rotate(0deg);
        }
        to {
          transform: rotate(180deg);
        }
      }
    </style>
@endsection
EOF

echo "Isi $TARGET_FILE sudah diganti dengan konten baru!"
echo ""
echo "✅ Fitur yang ditambahkan:"
echo "   - Notifikasi greeting personal"
echo "   - Notifikasi statistik server real-time"
echo "   - Progress bar status server"
echo "   - Tombol refresh statistik"
echo "   - Animasi dan transisi smooth"
echo ""
echo "📊 Server stats akan ditampilkan otomatis setelah login."
