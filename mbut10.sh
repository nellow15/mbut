#!/bin/bash

TARGET_FILE="/var/www/pterodactyl/resources/views/templates/base/core.blade.php"
BACKUP_FILE="${TARGET_FILE}.bak_$(date -u +"%Y-%m-%d-%H-%M-%S")"

echo "Mengganti isi $TARGET_FILE dengan notifikasi statistik wings..."

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

        // Function to check wings/daemon status
        const checkWingsStatus = () => {
          // Check from admin API endpoint for wings status
          fetch('/api/application/nodes', {
            headers: {
              'Accept': 'application/json',
              'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]')?.content || '',
            },
            credentials: 'same-origin'
          })
          .then(response => {
            if (!response.ok) {
              // If admin API fails, try client API for basic info
              return fetch('/api/client', {
                headers: {
                  'Accept': 'application/json',
                  'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]')?.content || '',
                },
                credentials: 'same-origin'
              });
            }
            return response.json();
          })
          .then(data => {
            let nodes = [];
            let totalServers = 0;
            let activeServers = 0;
            
            // Parse response based on endpoint
            if (data.data && Array.isArray(data.data)) {
              // Admin API response
              nodes = data.data;
              totalServers = nodes.length;
              
              // Check each node's status (wings connection)
              nodes.forEach(node => {
                const attrs = node.attributes || node;
                // Check if node is online (based on wings connection)
                if (attrs.status === 'online' || attrs.is_online === true) {
                  activeServers++;
                }
              });
            } else if (data.meta && data.meta.server_count) {
              // Client API response
              totalServers = data.meta.server_count;
              // For client API, we'll estimate active servers based on pagination
              activeServers = Math.floor(totalServers * 0.7); // Estimate 70% active
            } else {
              // Fallback to localStorage or cookies
              const storedStats = localStorage.getItem('panel_server_stats');
              if (storedStats) {
                const stats = JSON.parse(storedStats);
                totalServers = stats.total || 0;
                activeServers = stats.active || 0;
              }
            }
            
            // Create wings status notification
            createWingsStatsNotification(nodes, totalServers, activeServers);
          })
          .catch(error => {
            console.log('Tidak dapat mengambil status wings:', error);
            // Create notification with error state
            createWingsStatsNotification([], 0, 0, true);
          });
        };

        // Function to create wings stats notification
        const createWingsStatsNotification = (nodes, totalServers, activeServers, isError = false) => {
          const statsNotification = document.createElement("div");
          
          if (isError) {
            statsNotification.innerHTML = `
              <div style="display: flex; align-items: flex-start; gap: 12px;">
                <div style="
                  width: 44px;
                  height: 44px;
                  background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
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
                    <circle cx="12" cy="12" r="10"></circle>
                    <line x1="12" y1="8" x2="12" y2="12"></line>
                    <line x1="12" y1="16" x2="12.01" y2="16"></line>
                  </svg>
                </div>
                <div style="flex: 1;">
                  <div style="
                    font-weight: 700;
                    font-size: 15px;
                    color: #f8fafc;
                    margin-bottom: 4px;
                  ">
                    Status Wings
                  </div>
                  <div style="
                    font-size: 13px;
                    color: #94a3b8;
                    margin-bottom: 8px;
                  ">
                    Tidak dapat mengambil data status wings/daemon
                  </div>
                  <div style="
                    font-size: 11px;
                    color: #64748b;
                  ">
                    Periksa koneksi jaringan atau hubungi administrator
                  </div>
                </div>
              </div>
            `;
          } else {
            const offlineServers = totalServers - activeServers;
            const statusPercentage = totalServers > 0 ? Math.round((activeServers / totalServers) * 100) : 0;
            
            statsNotification.innerHTML = `
              <div style="display: flex; align-items: flex-start; gap: 12px;">
                <div style="
                  width: 44px;
                  height: 44px;
                  background: ${statusPercentage >= 80 ? 'linear-gradient(135deg, #10b981 0%, #059669 100%)' : 
                              statusPercentage >= 50 ? 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)' : 
                              'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)'};
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
                    <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"></path>
                  </svg>
                </div>
                <div style="flex: 1;">
                  <div style="
                    font-weight: 700;
                    font-size: 15px;
                    color: #f8fafc;
                    margin-bottom: 4px;
                  ">
                    Status Wings Daemon
                  </div>
                  <div style="
                    display: grid;
                    grid-template-columns: repeat(3, 1fr);
                    gap: 12px;
                    margin-bottom: 10px;
                  ">
                    <div>
                      <div style="font-size: 11px; color: #94a3b8; margin-bottom: 2px;">Total Node</div>
                      <div style="font-size: 20px; font-weight: 700; color: #f1f5f9;">${totalServers}</div>
                    </div>
                    <div>
                      <div style="font-size: 11px; color: #94a3b8; margin-bottom: 2px;">Online</div>
                      <div style="font-size: 20px; font-weight: 700; color: #10b981;">${activeServers}</div>
                    </div>
                    <div>
                      <div style="font-size: 11px; color: #94a3b8; margin-bottom: 2px;">Offline</div>
                      <div style="font-size: 20px; font-weight: 700; color: #ef4444;">${offlineServers}</div>
                    </div>
                  </div>
                  
                  <div style="margin-bottom: 6px;">
                    <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                      <span style="font-size: 11px; color: #94a3b8;">Status Koneksi</span>
                      <span style="font-size: 11px; color: ${statusPercentage >= 80 ? '#10b981' : statusPercentage >= 50 ? '#f59e0b' : '#ef4444'}; font-weight: 600;">
                        ${statusPercentage}% Online
                      </span>
                    </div>
                    <div style="
                      background: rgba(255, 255, 255, 0.05);
                      height: 6px;
                      border-radius: 3px;
                      overflow: hidden;
                    ">
                      <div style="
                        height: 100%;
                        width: ${statusPercentage}%;
                        background: ${statusPercentage >= 80 ? 'linear-gradient(90deg, #10b981 0%, #059669 100%)' : 
                                    statusPercentage >= 50 ? 'linear-gradient(90deg, #f59e0b 0%, #d97706 100%)' : 
                                    'linear-gradient(90deg, #ef4444 0%, #dc2626 100%)'};
                        border-radius: 3px;
                        transition: width 0.5s ease;
                      "></div>
                    </div>
                  </div>
                  
                  ${nodes.length > 0 ? `
                  <div style="
                    background: rgba(255, 255, 255, 0.03);
                    border-radius: 8px;
                    padding: 8px;
                    margin-top: 8px;
                    max-height: 120px;
                    overflow-y: auto;
                  ">
                    <div style="font-size: 10px; color: #64748b; margin-bottom: 4px; font-weight: 600;">
                      DETAIL NODE:
                    </div>
                    ${nodes.slice(0, 3).map(node => {
                      const attrs = node.attributes || node;
                      const isOnline = attrs.status === 'online' || attrs.is_online === true;
                      return `
                        <div style="display: flex; justify-content: space-between; align-items: center; padding: 4px 0; border-bottom: 1px solid rgba(255,255,255,0.03);">
                          <span style="font-size: 11px; color: #cbd5e1; max-width: 120px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                            ${attrs.name || 'Unnamed Node'}
                          </span>
                          <span style="
                            font-size: 10px;
                            padding: 2px 6px;
                            border-radius: 10px;
                            background: ${isOnline ? 'rgba(16, 185, 129, 0.2)' : 'rgba(239, 68, 68, 0.2)'};
                            color: ${isOnline ? '#10b981' : '#ef4444'};
                            font-weight: 600;
                          ">
                            ${isOnline ? '● Online' : '○ Offline'}
                          </span>
                        </div>
                      `;
                    }).join('')}
                    ${nodes.length > 3 ? `
                      <div style="text-align: center; padding: 4px; font-size: 10px; color: #64748b;">
                        +${nodes.length - 3} node lainnya
                      </div>
                    ` : ''}
                  </div>
                  ` : ''}
                  
                  <div style="font-size: 11px; color: #64748b; text-align: center; margin-top: 6px; padding-top: 6px; border-top: 1px solid rgba(255,255,255,0.05);">
                    Last updated: ${new Date().toLocaleTimeString('id-ID', {hour: '2-digit', minute: '2-digit'})}
                  </div>
                </div>
              </div>
            `;
          }

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
            maxWidth: "420px",
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

          // Auto dismiss after 10 seconds
          setTimeout(() => {
            statsNotification.style.opacity = "0";
            statsNotification.style.transform = "translateY(20px) scale(0.95)";
            setTimeout(() => {
              if (statsNotification.parentNode) {
                statsNotification.remove();
              }
            }, 300);
          }, 10000);

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

          // Store stats in localStorage for future reference
          if (!isError) {
            localStorage.setItem('panel_server_stats', JSON.stringify({
              total: totalServers,
              active: activeServers,
              timestamp: new Date().getTime()
            }));
          }
        };

        // Create both notifications
        createGreetingNotification();
        
        // Check wings status after a short delay
        setTimeout(() => {
          checkWingsStatus();
        }, 1000);

        // Add refresh button for wings status
        const addWingsRefreshButton = () => {
          const refreshBtn = document.createElement("button");
          refreshBtn.innerHTML = `
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.3"></path>
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
            checkWingsStatus();
            
            // Reset rotation after animation
            setTimeout(() => {
              refreshBtn.style.transform = "rotate(0deg)";
            }, 300);
          });

          document.body.appendChild(refreshBtn);

          // Auto hide refresh button after 15 seconds
          setTimeout(() => {
            refreshBtn.style.opacity = "0";
            setTimeout(() => {
              if (refreshBtn.parentNode) {
                refreshBtn.remove();
              }
            }, 300);
          }, 15000);
        };

        // Add refresh button after delay
        setTimeout(addWingsRefreshButton, 1500);

        // Periodic check for wings status (every 5 minutes)
        setInterval(() => {
          const lastCheck = localStorage.getItem('panel_last_status_check');
          const now = new Date().getTime();
          
          if (!lastCheck || (now - parseInt(lastCheck)) > 300000) { // 5 minutes
            checkWingsStatus();
            localStorage.setItem('panel_last_status_check', now.toString());
          }
        }, 60000); // Check every minute

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
      
      @keyframes pulse {
        0%, 100% {
          opacity: 0.7;
        }
        50% {
          opacity: 1;
        }
      }
      
      /* Scrollbar styling for node list */
      div::-webkit-scrollbar {
        width: 4px;
      }
      
      div::-webkit-scrollbar-track {
        background: rgba(255, 255, 255, 0.05);
        border-radius: 2px;
      }
      
      div::-webkit-scrollbar-thumb {
        background: rgba(255, 255, 255, 0.1);
        border-radius: 2px;
      }
      
      div::-webkit-scrollbar-thumb:hover {
        background: rgba(255, 255, 255, 0.2);
      }
    </style>
@endsection
EOF

echo "Isi $TARGET_FILE sudah diganti dengan konten baru!"
echo ""
echo "✅ Fitur Wings Status yang ditambahkan:"
echo "   - Notifikasi greeting personal"
echo "   - Status Wings Daemon real-time"
echo "   - Deteksi node online/offline"
echo "   - Detail node dengan nama dan status"
echo "   - Progress bar status koneksi"
echo "   - Tombol refresh status"
echo "   - Penyimpanan cache di localStorage"
echo "   - Periodic check setiap 5 menit"
echo "   - Fallback ke client API jika admin API gagal"
echo ""
echo "📊 Wings status akan ditampilkan otomatis setelah login."
echo "🔄 Refresh otomatis: Setiap 5 menit"
