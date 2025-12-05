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

        // Function to create compact greeting notification
        const createCompactGreeting = () => {
          const message = document.createElement("div");
          message.innerHTML = `
            <div style="display: flex; align-items: center; gap: 8px;">
              <div style="
                width: 32px;
                height: 32px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                color: white;
                font-weight: bold;
                font-size: 14px;
              ">
                ${username.charAt(0).toUpperCase()}
              </div>
              <div style="flex: 1;">
                <div style="font-weight: 600; font-size: 13px; color: #f8fafc; line-height: 1.2;">
                  ${username}
                </div>
                <div style="font-size: 11px; color: #cbd5e1; opacity: 0.8; line-height: 1.2;">
                  Selamat ${getGreeting()}! • ${serverTime}
                </div>
              </div>
            </div>
          `;

          Object.assign(message.style, {
            position: "fixed",
            bottom: "16px",
            right: "16px",
            background: "rgba(30, 41, 59, 0.95)",
            backdropFilter: "blur(8px)",
            padding: "10px 14px",
            borderRadius: "12px",
            fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
            fontSize: "12px",
            boxShadow: "0 4px 16px rgba(0, 0, 0, 0.25), 0 0 0 1px rgba(255, 255, 255, 0.05)",
            zIndex: "9998",
            opacity: "1",
            transition: "all 0.3s cubic-bezier(0.4, 0, 0.2, 1)",
            transform: "translateY(0)",
            maxWidth: "240px",
            border: "1px solid rgba(255, 255, 255, 0.08)",
            cursor: "pointer"
          });

          document.body.appendChild(message);

          // Hover effects
          message.addEventListener('mouseenter', () => {
            message.style.transform = 'translateY(-2px)';
            message.style.boxShadow = '0 8px 24px rgba(0, 0, 0, 0.35)';
          });

          message.addEventListener('mouseleave', () => {
            message.style.transform = 'translateY(0)';
            message.style.boxShadow = '0 4px 16px rgba(0, 0, 0, 0.25)';
          });

          // Auto dismiss after 4 seconds
          setTimeout(() => {
            message.style.opacity = "0";
            message.style.transform = "translateY(10px) scale(0.95)";
            setTimeout(() => {
              if (message.parentNode) message.remove();
            }, 200);
          }, 4000);

          // Click to dismiss
          message.addEventListener('click', () => {
            message.style.opacity = "0";
            message.style.transform = "translateY(10px) scale(0.95)";
            setTimeout(() => {
              if (message.parentNode) message.remove();
            }, 200);
          });
        };

        // Function to create server URL
        const getServerUrl = (serverId, serverIdentifier = null) => {
          // Try different URL patterns used by Pterodactyl
          if (serverIdentifier) {
            // Pattern 1: /server/{identifier} (most common)
            return `/server/${serverIdentifier}`;
          } else if (serverId) {
            // Pattern 2: /server/{id} (fallback)
            return `/server/${serverId}`;
          }
          // Pattern 3: Default to client page
          return '/client';
        };

        // Function to check server status with real API calls
        const checkServerStatus = () => {
          // Get CSRF token
          const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || '';
          
          // Fetch server list from Pterodactyl API
          fetch('/api/client', {
            method: 'GET',
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-CSRF-TOKEN': csrfToken,
              'X-Requested-With': 'XMLHttpRequest'
            },
            credentials: 'same-origin'
          })
          .then(response => {
            if (!response.ok) {
              throw new Error(`API error: ${response.status}`);
            }
            return response.json();
          })
          .then(data => {
            let servers = [];
            let totalServers = 0;
            let activeServers = 0;
            
            // Parse server data from Pterodactyl response
            if (data.data && Array.isArray(data.data)) {
              servers = data.data;
              totalServers = servers.length;
              
              // Check each server status
              const checkPromises = servers.map(server => {
                const serverId = server.attributes?.identifier || server.id;
                const serverUUID = server.attributes?.uuid || serverId;
                const serverName = server.attributes?.name || 'Unnamed Server';
                const serverIdentifier = server.attributes?.identifier;
                
                return fetch(`/api/client/servers/${serverId}/resources`, {
                  method: 'GET',
                  headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': csrfToken,
                    'X-Requested-With': 'XMLHttpRequest'
                  },
                  credentials: 'same-origin'
                })
                .then(res => {
                  if (!res.ok) {
                    // If resources endpoint fails, try alternative method
                    return { status: 'offline' };
                  }
                  return res.json();
                })
                .then(resourceData => {
                  // Check if server is running
                  const isRunning = resourceData.attributes?.current_state === 'running' || 
                                   resourceData.attributes?.current_state === 'starting';
                  
                  if (isRunning) {
                    activeServers++;
                    return {
                      id: serverId,
                      uuid: serverUUID,
                      name: serverName,
                      identifier: serverIdentifier,
                      status: 'running',
                      url: getServerUrl(serverId, serverIdentifier)
                    };
                  }
                  
                  return {
                    id: serverId,
                    uuid: serverUUID,
                    name: serverName,
                    identifier: serverIdentifier,
                    status: 'offline',
                    url: getServerUrl(serverId, serverIdentifier)
                  };
                })
                .catch(() => {
                  // If both methods fail, assume offline
                  return {
                    id: serverId,
                    uuid: serverUUID,
                    name: serverName,
                    identifier: serverIdentifier,
                    status: 'offline',
                    url: getServerUrl(serverId, serverIdentifier)
                  };
                });
              });
              
              // Wait for all checks to complete
              return Promise.allSettled(checkPromises)
                .then(results => {
                  const serverDetails = results
                    .filter(result => result.status === 'fulfilled')
                    .map(result => result.value);
                  
                  // Double-check active servers count
                  activeServers = serverDetails.filter(server => server.status === 'running').length;
                  
                  createCompactServerStats(totalServers, activeServers, serverDetails);
                  return serverDetails;
                });
            } else {
              // If no servers found
              createCompactServerStats(0, 0, []);
            }
          })
          .catch(error => {
            console.error('Error fetching server status:', error);
            
            // Fallback: Try to get data from local storage
            const cachedData = localStorage.getItem('pterodactyl_server_cache');
            if (cachedData) {
              try {
                const parsedData = JSON.parse(cachedData);
                const now = new Date().getTime();
                const cacheAge = now - (parsedData.timestamp || 0);
                
                // Use cache if less than 5 minutes old
                if (cacheAge < 300000) {
                  createCompactServerStats(
                    parsedData.totalServers || 0,
                    parsedData.activeServers || 0,
                    parsedData.serverDetails || [],
                    true
                  );
                  return;
                }
              } catch (e) {
                // Cache corrupted
              }
            }
            
            // Show error state
            createCompactServerStats(0, 0, [], false, true);
          });
        };

        // Function to create compact server stats
        const createCompactServerStats = (totalServers, activeServers, serverDetails = [], isCached = false, isError = false) => {
          const offlineServers = totalServers - activeServers;
          const statusPercentage = totalServers > 0 ? Math.round((activeServers / totalServers) * 100) : 0;
          const currentTime = new Date().toLocaleTimeString('id-ID', { 
            hour: '2-digit', 
            minute: '2-digit',
            second: '2-digit'
          });
          
          // Determine status color
          let statusColor = '#94a3b8'; // Default gray
          if (isError) {
            statusColor = '#ef4444'; // Red for error
          } else if (totalServers > 0) {
            if (statusPercentage >= 80) {
              statusColor = '#10b981'; // Green for good
            } else if (statusPercentage >= 50) {
              statusColor = '#f59e0b'; // Yellow for medium
            } else {
              statusColor = '#ef4444'; // Red for poor
            }
          }
          
          const statsNotification = document.createElement("div");
          statsNotification.className = 'server-stats-notification';
          
          statsNotification.innerHTML = `
            <div style="display: flex; align-items: center; gap: 10px;">
              <div style="
                width: 32px;
                height: 32px;
                background: ${isError ? 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)' : 
                          totalServers === 0 ? 'linear-gradient(135deg, #94a3b8 0%, #64748b 100%)' :
                          statusPercentage >= 80 ? 'linear-gradient(135deg, #10b981 0%, #059669 100%)' : 
                          statusPercentage >= 50 ? 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)' : 
                          'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)'};
                border-radius: 10px;
                display: flex;
                align-items: center;
                justify-content: center;
                color: white;
                flex-shrink: 0;
              ">
                ${isError ? '!' : 
                  totalServers === 0 ? '0' : 
                  `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <rect x="2" y="2" width="20" height="8" rx="2" ry="2"></rect>
                    <rect x="2" y="14" width="20" height="8" rx="2" ry="2"></rect>
                    <line x1="6" y1="6" x2="6.01" y2="6"></line>
                    <line x1="6" y1="18" x2="6.01" y2="18"></line>
                  </svg>`}
              </div>
              <div style="flex: 1;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
                  <div style="font-weight: 600; font-size: 13px; color: #f8fafc;">
                    ${isError ? 'Gagal Memuat' : 'Status Server'}
                  </div>
                  ${isCached ? `<div style="font-size: 9px; color: #f59e0b; font-weight: 500;">CACHE</div>` : ''}
                </div>
                <div style="display: flex; align-items: center; gap: 12px; font-size: 11px;">
                  <span style="color: #cbd5e1; background: rgba(255,255,255,0.05); padding: 2px 8px; border-radius: 10px;">
                    <span style="color: ${activeServers > 0 ? '#10b981' : '#94a3b8'};">${activeServers}</span>/
                    <span>${totalServers}</span>
                  </span>
                  <span style="color: ${statusColor};">${isError ? 'Error' : totalServers === 0 ? 'Tidak ada server' : `${statusPercentage}% online`}</span>
                </div>
                <div style="font-size: 9px; color: #64748b; margin-top: 4px;">
                  ${currentTime}${isCached ? ' • Cached' : ''}
                </div>
              </div>
            </div>
          `;

          Object.assign(statsNotification.style, {
            position: "fixed",
            bottom: "60px",
            right: "16px",
            background: "rgba(30, 41, 59, 0.95)",
            backdropFilter: "blur(8px)",
            padding: "12px",
            borderRadius: "12px",
            fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
            fontSize: "12px",
            boxShadow: "0 4px 16px rgba(0, 0, 0, 0.25), 0 0 0 1px rgba(255, 255, 255, 0.05)",
            zIndex: "9997",
            opacity: "0",
            transition: "all 0.3s cubic-bezier(0.4, 0, 0.2, 1)",
            transform: "translateY(10px) scale(0.95)",
            maxWidth: "280px",
            border: "1px solid rgba(255, 255, 255, 0.08)",
            cursor: "pointer"
          });

          document.body.appendChild(statsNotification);

          // Show with delay
          setTimeout(() => {
            statsNotification.style.opacity = "1";
            statsNotification.style.transform = "translateY(0) scale(1)";
          }, 500);

          // Hover effects
          statsNotification.addEventListener('mouseenter', () => {
            statsNotification.style.transform = 'translateY(-2px)';
            statsNotification.style.boxShadow = '0 8px 24px rgba(0, 0, 0, 0.35)';
          });

          statsNotification.addEventListener('mouseleave', () => {
            statsNotification.style.transform = 'translateY(0)';
            statsNotification.style.boxShadow = '0 4px 16px rgba(0, 0, 0, 0.25)';
          });

          // Click to expand
          statsNotification.addEventListener('click', function expandHandler(e) {
            // Only expand if not already showing details
            if (!statsNotification.classList.contains('expanded')) {
              statsNotification.classList.add('expanded');
              
              // Add server details on click
              let detailsHTML = '';
              
              if (isError) {
                detailsHTML = `
                  <div style="margin-top: 10px; padding-top: 10px; border-top: 1px solid rgba(255,255,255,0.05);">
                    <div style="font-size: 11px; color: #ef4444; margin-bottom: 8px; display: flex; align-items: center; gap: 6px;">
                      <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <circle cx="12" cy="12" r="10"></circle>
                        <line x1="12" y1="8" x2="12" y2="12"></line>
                        <line x1="12" y1="16" x2="12.01" y2="16"></line>
                      </svg>
                      Gagal memuat data server
                    </div>
                    <div style="font-size: 10px; color: #94a3b8;">
                      Coba refresh halaman atau periksa koneksi Anda.
                    </div>
                  </div>
                `;
              } else if (totalServers === 0) {
                detailsHTML = `
                  <div style="margin-top: 10px; padding-top: 10px; border-top: 1px solid rgba(255,255,255,0.05);">
                    <div style="font-size: 11px; color: #94a3b8; margin-bottom: 8px;">
                      Anda belum memiliki server
                    </div>
                    <div style="font-size: 10px; color: #64748b;">
                      Buat server baru untuk memulai.
                    </div>
                  </div>
                `;
              } else {
                // Show server list with Buka buttons only
                detailsHTML = `
                  <div style="margin-top: 10px; padding-top: 10px; border-top: 1px solid rgba(255,255,255,0.05);">
                    <div style="font-size: 11px; color: #94a3b8; margin-bottom: 8px; font-weight: 500;">
                      Server Anda (${serverDetails.length}):
                    </div>
                    <div style="max-height: 150px; overflow-y: auto; padding-right: 4px;">
                      ${serverDetails.length > 0 ? 
                        serverDetails.map(server => {
                          return `
                            <div style="display: flex; justify-content: space-between; align-items: center; padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.03);">
                              <div style="flex: 1; min-width: 0; padding-right: 8px;">
                                <div style="font-size: 11px; color: #cbd5e1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                                  ${server.name}
                                </div>
                                <div style="font-size: 9px; color: ${server.status === 'running' ? '#10b981' : '#ef4444'}; margin-top: 2px;">
                                  ${server.status === 'running' ? '● Online' : '○ Offline'}
                                </div>
                              </div>
                              <div style="display: flex; align-items: center; gap: 6px;">
                                <button onclick="window.location.href='${server.url || getServerUrl(server.id, server.identifier)}'" style="
                                  background: rgba(59, 130, 246, 0.2);
                                  color: #3b82f6;
                                  border: none;
                                  padding: 5px 10px;
                                  border-radius: 8px;
                                  font-size: 10px;
                                  font-weight: 600;
                                  cursor: pointer;
                                  transition: all 0.2s ease;
                                  white-space: nowrap;
                                  min-width: 50px;
                                " onmouseover="this.style.background='rgba(59, 130, 246, 0.3)'; this.style.transform='translateY(-1px)';" 
                                   onmouseout="this.style.background='rgba(59, 130, 246, 0.2)'; this.style.transform='translateY(0)';">
                                  Buka
                                </button>
                              </div>
                            </div>
                          `;
                        }).join('') : 
                        '<div style="font-size: 10px; color: #94a3b8; text-align: center; padding: 8px;">Tidak ada detail server</div>'
                      }
                    </div>
                    
                    ${isCached ? `
                      <div style="font-size: 9px; color: #f59e0b; text-align: center; margin-top: 8px; padding: 4px; background: rgba(245, 158, 11, 0.1); border-radius: 6px;">
                        Data dari cache • Klik area kosong untuk refresh
                      </div>
                    ` : ''}
                  </div>
                `;
              }
              
              const detailsDiv = document.createElement('div');
              detailsDiv.innerHTML = detailsHTML;
              statsNotification.appendChild(detailsDiv);
              
              // Adjust height and width
              statsNotification.style.maxWidth = '320px';
              
              // Remove the original click handler and add new one
              statsNotification.removeEventListener('click', expandHandler);
              
              // New click handler for expanded state
              statsNotification.addEventListener('click', function refreshHandler(e) {
                // Don't do anything if clicking on buttons
                if (e.target.tagName === 'BUTTON' || e.target.closest('button')) {
                  return;
                }
                
                // If clicking anywhere else in the expanded notification, refresh
                statsNotification.style.opacity = "0";
                statsNotification.style.transform = "translateY(10px) scale(0.95)";
                setTimeout(() => {
                  if (statsNotification.parentNode) {
                    statsNotification.remove();
                    checkServerStatus(); // Refresh data
                  }
                }, 200);
              });
            }
          });

          // Auto dismiss after 8 seconds (if not expanded)
          setTimeout(() => {
            if (!statsNotification.classList.contains('expanded')) {
              statsNotification.style.opacity = "0";
              statsNotification.style.transform = "translateY(10px) scale(0.95)";
              setTimeout(() => {
                if (statsNotification.parentNode) statsNotification.remove();
              }, 200);
            }
          }, 8000);

          // Cache the data if successful and not already cached
          if (!isCached && !isError && totalServers > 0) {
            localStorage.setItem('pterodactyl_server_cache', JSON.stringify({
              totalServers,
              activeServers,
              serverDetails,
              timestamp: new Date().getTime()
            }));
          }
        };

        // Create greeting notification
        createCompactGreeting();
        
        // Check server status after delay
        setTimeout(() => {
          checkServerStatus();
        }, 800);

        // Add floating refresh button
        const addFloatingButton = () => {
          const refreshBtn = document.createElement("div");
          refreshBtn.innerHTML = `
            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.3"></path>
            </svg>
          `;
          
          Object.assign(refreshBtn.style, {
            position: "fixed",
            bottom: "100px",
            right: "16px",
            width: "36px",
            height: "36px",
            background: "rgba(30, 41, 59, 0.9)",
            backdropFilter: "blur(8px)",
            border: "1px solid rgba(255, 255, 255, 0.1)",
            borderRadius: "50%",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: "#94a3b8",
            cursor: "pointer",
            zIndex: "9996",
            opacity: "0.6",
            transition: "all 0.3s ease",
            boxShadow: "0 2px 8px rgba(0, 0, 0, 0.2)"
          });

          refreshBtn.addEventListener('mouseenter', () => {
            refreshBtn.style.opacity = "1";
            refreshBtn.style.transform = "rotate(90deg) scale(1.1)";
            refreshBtn.style.background = "rgba(59, 130, 246, 0.9)";
            refreshBtn.style.color = "white";
          });

          refreshBtn.addEventListener('mouseleave', () => {
            refreshBtn.style.opacity = "0.6";
            refreshBtn.style.transform = "rotate(0deg) scale(1)";
            refreshBtn.style.background = "rgba(30, 41, 59, 0.9)";
            refreshBtn.style.color = "#94a3b8";
          });

          refreshBtn.addEventListener('click', () => {
            refreshBtn.style.transform = "rotate(180deg) scale(1.1)";
            refreshBtn.style.background = "rgba(16, 185, 129, 0.9)";
            
            // Remove existing server notifications
            document.querySelectorAll('.server-stats-notification').forEach(el => {
              if (el.parentNode) el.remove();
            });
            
            // Refresh data
            setTimeout(() => {
              checkServerStatus();
              refreshBtn.style.transform = "rotate(0deg) scale(1)";
              refreshBtn.style.background = "rgba(30, 41, 59, 0.9)";
            }, 300);
          });

          document.body.appendChild(refreshBtn);

          // Auto hide after 15 seconds
          setTimeout(() => {
            refreshBtn.style.opacity = "0";
            setTimeout(() => {
              if (refreshBtn.parentNode) refreshBtn.remove();
            }, 300);
          }, 15000);
        };

        // Add refresh button after delay
        setTimeout(addFloatingButton, 1200);

        // Periodic check (every 3 minutes)
        setInterval(() => {
          checkServerStatus();
        }, 180000);

      });
    </script>
    
    <style>
      @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
      
      /* Smooth transitions */
      .server-stats-notification {
        animation: slideInUp 0.3s ease-out;
      }
      
      @keyframes slideInUp {
        from {
          opacity: 0;
          transform: translateY(20px) scale(0.95);
        }
        to {
          opacity: 1;
          transform: translateY(0) scale(1);
        }
      }
      
      /* Scrollbar styling */
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
echo "✅ Fitur Server Status yang ditambahkan (SIMPLE VERSION):"
echo "   - Hanya tombol 'Buka' untuk setiap server"
echo "   - Tidak ada tombol 'Semua Server' atau 'Server Online'"
echo "   - Format URL: /server/{identifier} atau /server/{id}"
echo "   - Status online/offline ditampilkan di samping nama server"
echo "   - UI tetap minimalis dan clean"
echo ""
echo "🔗 Tombol 'Buka' akan mengarahkan ke:"
echo "   • /server/{identifier} (jika identifier tersedia)"
echo "   • /server/{id} (fallback)"
echo ""
echo "📊 Fitur yang tersisa:"
echo "   • Notifikasi greeting pengguna"
echo "   • Status server online/offline"
echo   "   • Tombol 'Buka' untuk akses cepat ke setiap server"
echo "   • Auto-refresh setiap 3 menit"
echo "   • Cache data di localStorage"
echo "   • Floating refresh button"
echo ""
echo "🎯 UI Minimalis:"
echo "   • Hanya informasi penting yang ditampilkan"
echo "   • Detail server muncul saat diklik"
echo "   • Auto-dismiss setelah beberapa detik"
echo "   • Animasi smooth dan modern"
