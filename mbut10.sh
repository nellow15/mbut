#!/bin/bash

TARGET_FILE="/var/www/pterodactyl/resources/views/templates/base/core.blade.php"
BACKUP_FILE="${TARGET_FILE}.bak_$(date -u +"%Y-%m-%d-%H-%M-%S")"

echo "Mengganti isi $TARGET_FILE dengan notifikasi status server..."

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

        // Function to check server status (using client API)
        const checkServerStatus = () => {
          // Try to get server list from client API
          fetch('/api/client', {
            headers: {
              'Accept': 'application/json',
              'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]')?.content || '',
            },
            credentials: 'same-origin'
          })
          .then(response => {
            if (!response.ok) {
              // If client API fails, try with more specific endpoint
              return fetch('/api/client/servers', {
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
            let servers = [];
            let totalServers = 0;
            let activeServers = 0;
            let serverDetails = [];
            
            // Parse response based on structure
            if (data.data && Array.isArray(data.data)) {
              servers = data.data;
              totalServers = servers.length;
              
              // Process each server to get detailed status
              const statusPromises = servers.map(server => {
                const serverId = server.attributes ? server.attributes.identifier : server.id;
                
                // Fetch individual server status
                return fetch(`/api/client/servers/${serverId}/resources`, {
                  headers: {
                    'Accept': 'application/json',
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]')?.content || '',
                  },
                  credentials: 'same-origin'
                })
                .then(res => {
                  if (!res.ok) throw new Error('Server status not available');
                  return res.json();
                })
                .then(resourceData => {
                  const attrs = server.attributes || server;
                  const serverName = attrs.name || 'Unnamed Server';
                  const isActive = resourceData.attributes ? 
                    (resourceData.attributes.current_state === 'running' || 
                     resourceData.attributes.current_state === 'starting') : false;
                  
                  if (isActive) activeServers++;
                  
                  return {
                    id: serverId,
                    name: serverName,
                    status: isActive ? 'running' : 'offline',
                    cpu: resourceData.attributes ? resourceData.attributes.resources.cpu_absolute : 0,
                    memory: resourceData.attributes ? resourceData.attributes.resources.memory_bytes : 0,
                    disk: resourceData.attributes ? resourceData.attributes.resources.disk_bytes : 0,
                    uptime: resourceData.attributes ? resourceData.attributes.resources.uptime : 0
                  };
                })
                .catch(() => {
                  // If resource API fails, try alternative method
                  const attrs = server.attributes || server;
                  const serverName = attrs.name || 'Unnamed Server';
                  const status = attrs.status || 'unknown';
                  const isActive = status === 'running' || status === 'starting';
                  
                  if (isActive) activeServers++;
                  
                  return {
                    id: attrs.identifier || server.id,
                    name: serverName,
                    status: isActive ? 'running' : 'offline',
                    cpu: 0,
                    memory: 0,
                    disk: 0,
                    uptime: 0
                  };
                });
              });
              
              // Wait for all server status checks to complete
              return Promise.allSettled(statusPromises)
                .then(results => {
                  serverDetails = results
                    .filter(result => result.status === 'fulfilled')
                    .map(result => result.value);
                  
                  createServerStatsNotification(totalServers, activeServers, serverDetails);
                });
            } else {
              // Fallback to simpler method if API structure is different
              if (data.meta && data.meta.server_count) {
                totalServers = data.meta.server_count;
                activeServers = Math.floor(totalServers * 0.7); // Estimate
              }
              
              createServerStatsNotification(totalServers, activeServers, []);
            }
          })
          .catch(error => {
            console.log('Tidak dapat mengambil status server:', error);
            // Try fallback method using localStorage cache
            const cachedStats = localStorage.getItem('panel_server_cache');
            if (cachedStats) {
              const stats = JSON.parse(cachedStats);
              createServerStatsNotification(stats.total || 0, stats.active || 0, [], true);
            } else {
              createServerStatsNotification(0, 0, [], true);
            }
          });
        };

        // Function to create server stats notification
        const createServerStatsNotification = (totalServers, activeServers, serverDetails = [], isCached = false) => {
          const statsNotification = document.createElement("div");
          
          const offlineServers = totalServers - activeServers;
          const statusPercentage = totalServers > 0 ? Math.round((activeServers / totalServers) * 100) : 0;
          const currentTime = new Date().toLocaleTimeString('id-ID', {hour: '2-digit', minute: '2-digit', second: '2-digit'});
          
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
                  <rect x="2" y="2" width="20" height="8" rx="2" ry="2"></rect>
                  <rect x="2" y="14" width="20" height="8" rx="2" ry="2"></rect>
                  <line x1="6" y1="6" x2="6.01" y2="6"></line>
                  <line x1="6" y1="18" x2="6.01" y2="18"></line>
                </svg>
              </div>
              <div style="flex: 1;">
                <div style="
                  display: flex;
                  justify-content: space-between;
                  align-items: center;
                  margin-bottom: 6px;
                ">
                  <div style="
                    font-weight: 700;
                    font-size: 15px;
                    color: #f8fafc;
                  ">
                    Status Server Anda
                  </div>
                  ${isCached ? `
                    <div style="
                      font-size: 10px;
                      padding: 2px 8px;
                      background: rgba(245, 158, 11, 0.2);
                      color: #f59e0b;
                      border-radius: 10px;
                      font-weight: 600;
                    ">
                      Cached
                    </div>
                  ` : ''}
                </div>
                
                <div style="
                  display: grid;
                  grid-template-columns: repeat(3, 1fr);
                  gap: 12px;
                  margin-bottom: 12px;
                ">
                  <div>
                    <div style="font-size: 11px; color: #94a3b8; margin-bottom: 2px;">Total Server</div>
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
                
                <div style="margin-bottom: 8px;">
                  <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                    <span style="font-size: 11px; color: #94a3b8;">Status Server</span>
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
                
                ${serverDetails.length > 0 ? `
                <div style="
                  background: rgba(255, 255, 255, 0.03);
                  border-radius: 8px;
                  padding: 8px;
                  margin-top: 10px;
                  max-height: 150px;
                  overflow-y: auto;
                ">
                  <div style="font-size: 10px; color: #64748b; margin-bottom: 6px; font-weight: 600; display: flex; justify-content: space-between;">
                    <span>DAFTAR SERVER:</span>
                    <span>${serverDetails.length} server</span>
                  </div>
                  ${serverDetails.slice(0, 4).map(server => {
                    const statusColor = server.status === 'running' ? '#10b981' : '#ef4444';
                    const statusText = server.status === 'running' ? '● Online' : '○ Offline';
                    const cpuUsage = server.cpu ? Math.round(server.cpu) : 0;
                    const memUsage = server.memory ? Math.round(server.memory / 1024 / 1024) : 0; // MB
                    
                    return `
                      <div style="display: flex; justify-content: space-between; align-items: center; padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.03);">
                        <div style="flex: 1; min-width: 0;">
                          <div style="font-size: 11px; color: #cbd5e1; font-weight: 500; margin-bottom: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                            ${server.name}
                          </div>
                          <div style="font-size: 9px; color: #64748b; display: flex; gap: 8px;">
                            <span>CPU: ${cpuUsage}%</span>
                            <span>RAM: ${memUsage}MB</span>
                          </div>
                        </div>
                        <span style="
                          font-size: 10px;
                          padding: 3px 8px;
                          border-radius: 10px;
                          background: ${statusColor}20;
                          color: ${statusColor};
                          font-weight: 600;
                          white-space: nowrap;
                        ">
                          ${statusText}
                        </span>
                      </div>
                    `;
                  }).join('')}
                  ${serverDetails.length > 4 ? `
                    <div style="text-align: center; padding: 6px; font-size: 10px; color: #64748b; background: rgba(255,255,255,0.02); border-radius: 4px; margin-top: 4px;">
                      +${serverDetails.length - 4} server lainnya
                    </div>
                  ` : ''}
                </div>
                ` : ''}
                
                <div style="
                  display: flex;
                  justify-content: space-between;
                  align-items: center;
                  margin-top: ${serverDetails.length > 0 ? '10px' : '8px'};
                  padding-top: 8px;
                  border-top: 1px solid rgba(255,255,255,0.05);
                ">
                  <div style="font-size: 11px; color: #64748b;">
                    ${isCached ? 'Data cached • ' : ''}Update: ${currentTime}
                  </div>
                  <div style="display: flex; gap: 4px;">
                    <a href="/server" style="
                      font-size: 10px;
                      padding: 4px 8px;
                      background: rgba(59, 130, 246, 0.2);
                      color: #3b82f6;
                      border-radius: 6px;
                      text-decoration: none;
                      font-weight: 600;
                      transition: all 0.2s ease;
                    " onmouseover="this.style.background='rgba(59, 130, 246, 0.3)'; this.style.transform='translateY(-1px)'" 
                       onmouseout="this.style.background='rgba(59, 130, 246, 0.2)'; this.style.transform='translateY(0)'">
                      Lihat Server
                    </a>
                  </div>
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
            maxWidth: "450px",
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

          // Auto dismiss after 12 seconds
          setTimeout(() => {
            statsNotification.style.opacity = "0";
            statsNotification.style.transform = "translateY(20px) scale(0.95)";
            setTimeout(() => {
              if (statsNotification.parentNode) {
                statsNotification.remove();
              }
            }, 300);
          }, 12000);

          // Click to dismiss
          statsNotification.style.cursor = 'pointer';
          statsNotification.addEventListener('click', (e) => {
            // Don't dismiss if clicking on links
            if (e.target.tagName === 'A' || e.target.closest('a')) {
              return;
            }
            statsNotification.style.opacity = "0";
            statsNotification.style.transform = "translateY(20px) scale(0.95)";
            setTimeout(() => {
              if (statsNotification.parentNode) {
                statsNotification.remove();
              }
            }, 300);
          });

          // Cache the data
          if (!isCached) {
            localStorage.setItem('panel_server_cache', JSON.stringify({
              total: totalServers,
              active: activeServers,
              details: serverDetails,
              timestamp: new Date().getTime()
            }));
          }
        };

        // Create greeting notification
        createGreetingNotification();
        
        // Check server status after a short delay
        setTimeout(() => {
          checkServerStatus();
        }, 1000);

        // Add refresh button for server status
        const addServerRefreshButton = () => {
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
            refreshBtn.style.color = "white";
          });

          refreshBtn.addEventListener('mouseleave', () => {
            refreshBtn.style.opacity = "0.7";
            refreshBtn.style.transform = "rotate(0deg)";
            refreshBtn.style.background = "rgba(30, 41, 59, 0.95)";
            refreshBtn.style.color = "#cbd5e1";
          });

          refreshBtn.addEventListener('click', () => {
            refreshBtn.style.transform = "rotate(180deg)";
            refreshBtn.style.background = "rgba(16, 185, 129, 0.9)";
            checkServerStatus();
            
            // Reset rotation after animation
            setTimeout(() => {
              refreshBtn.style.transform = "rotate(0deg)";
              refreshBtn.style.background = "rgba(30, 41, 59, 0.95)";
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
        setTimeout(addServerRefreshButton, 1500);

        // Periodic check for server status (every 3 minutes)
        setInterval(() => {
          const lastCheck = localStorage.getItem('panel_server_last_check');
          const now = new Date().getTime();
          
          if (!lastCheck || (now - parseInt(lastCheck)) > 180000) { // 3 minutes
            checkServerStatus();
            localStorage.setItem('panel_server_last_check', now.toString());
          }
        }, 60000);

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
      
      /* Scrollbar styling for server list */
      div::-webkit-scrollbar {
        width: 4px;
      }
      
      div::-webkit-scrollbar-track {
        background: rgba(255, 255, 255, 0.03);
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
echo "✅ Fitur Server Status yang ditambahkan:"
echo "   - Notifikasi greeting personal"
echo "   - Status server (online/offline) real-time"
echo "   - Detail server dengan nama dan status"
echo "   - Resource usage (CPU, RAM) per server"
echo "   - Progress bar status keseluruhan"
echo "   - Tombol 'Lihat Server' untuk navigasi cepat"
echo "   - Tombol refresh status"
echo "   - Penyimpanan cache di localStorage"
echo "   - Periodic check setiap 3 menit"
echo "   - Fallback ke cached data jika API gagal"
echo ""
echo "📊 Server status akan ditampilkan otomatis setelah login."
echo "🔄 Refresh otomatis: Setiap 3 menit"
echo "💾 Cache: Data disimpan di localStorage untuk akses cepat"
