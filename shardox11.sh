#!/bin/bash

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/NodesController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "Memulai proses instalasi proteksi Node Management..."

# Backup file lama jika ada
if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "Backup file lama berhasil dibuat di: $BACKUP_PATH"
fi

# Pastikan folder tujuan ada & izin benar
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

# Tulis file baru
cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Http\RedirectResponse;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Models\Node;
use Pterodactyl\Models\Allocation;
use Pterodactyl\Http\Controllers\Controller;
use Prologue\Alerts\AlertsMessageBag;
use Pterodactyl\Services\Nodes\NodeUpdateService;
use Pterodactyl\Services\Nodes\NodeCreationService;
use Pterodactyl\Services\Nodes\NodeDeletionService;
use Pterodactyl\Services\Allocations\AssignmentService;
use Pterodactyl\Services\Allocations\AllocationDeletionService;
use Pterodactyl\Contracts\Repository\NodeRepositoryInterface;
use Pterodactyl\Contracts\Repository\ServerRepositoryInterface;
use Pterodactyl\Contracts\Repository\LocationRepositoryInterface;
use Pterodactyl\Contracts\Repository\AllocationRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Node\NodeFormRequest;
use Pterodactyl\Http\Requests\Admin\Node\AllocationFormRequest;
use Pterodactyl\Http\Requests\Admin\Node\AllocationAliasFormRequest;
use Pterodactyl\Services\Helpers\SoftwareVersionService;

class NodesController extends Controller
{
    public function __construct(
        protected AlertsMessageBag $alert,
        protected AllocationDeletionService $allocationDeletionService,
        protected AllocationRepositoryInterface $allocationRepository,
        protected AssignmentService $assignmentService,
        protected NodeCreationService $creationService,
        protected NodeDeletionService $deletionService,
        protected LocationRepositoryInterface $locationRepository,
        protected NodeRepositoryInterface $repository,
        protected ServerRepositoryInterface $serverRepository,
        protected NodeUpdateService $updateService,
        protected SoftwareVersionService $versionService,
        protected ViewFactory $view
    ) {}

    /**
     * Membuat node baru.
     */
    public function create(): View|RedirectResponse
    {
        $locations = $this->locationRepository->all();
        if (count($locations) < 1) {
            $this->alert->warning(trans('admin/node.notices.location_required'))->flash();
            return redirect()->route('admin.locations');
        }

        return $this->view->make('admin.nodes.new', ['locations' => $locations]);
    }

    /**
     * Simpan node baru.
     */
    public function store(NodeFormRequest $request): RedirectResponse
    {
        $user = auth()->user();
        if ($user->id !== 1) {
            $this->logUnauthorizedAccess($user, 'create_node');
            abort(403, $this->getPermissionDeniedMessage('CREATE_NODE'));
        }

        $node = $this->creationService->handle($request->normalize());
        $this->alert->success(trans('admin/node.notices.node_created'))->flash();
        
        // Log aktivitas sukses
        activity()
            ->causedBy($user)
            ->withProperties([
                'node_id' => $node->id,
                'node_name' => $node->name,
                'action' => 'node_created'
            ])
            ->log('Node berhasil dibuat');
            
        return redirect()->route('admin.nodes.view.allocation', $node->id);
    }

    /**
     * Update node (khusus Admin ID 1).
     */
    public function updateSettings(NodeFormRequest $request, Node $node): RedirectResponse
    {
        $user = auth()->user();
        if ($user->id !== 1) {
            $this->logUnauthorizedAccess($user, 'update_node', $node->id);
            abort(403, $this->getPermissionDeniedMessage('UPDATE_NODE'));
        }

        $this->updateService->handle($node, $request->normalize(), $request->input('reset_secret') === 'on');
        $this->alert->success(trans('admin/node.notices.node_updated'))->flash();
        
        // Log aktivitas sukses
        activity()
            ->causedBy($user)
            ->withProperties([
                'node_id' => $node->id,
                'node_name' => $node->name,
                'action' => 'node_updated'
            ])
            ->log('Konfigurasi node berhasil diperbarui');
            
        return redirect()->route('admin.nodes.view.settings', $node->id)->withInput();
    }

    /**
     * Hapus node (khusus Admin ID 1).
     */
    public function delete(int|Node $node): RedirectResponse
    {
        $user = auth()->user();
        if ($user->id !== 1) {
            $this->logUnauthorizedAccess($user, 'delete_node', is_object($node) ? $node->id : $node);
            abort(403, $this->getPermissionDeniedMessage('DELETE_NODE'));
        }

        // Ambil data node sebelum dihapus untuk logging
        $nodeData = is_object($node) ? $node : Node::findOrFail($node);
        
        $this->deletionService->handle($node);
        $this->alert->success(trans('admin/node.notices.node_deleted'))->flash();
        
        // Log aktivitas sukses
        activity()
            ->causedBy($user)
            ->withProperties([
                'node_id' => $nodeData->id,
                'node_name' => $nodeData->name,
                'action' => 'node_deleted'
            ])
            ->log('Node berhasil dihapus dari sistem');
            
        return redirect()->route('admin.nodes');
    }

    /**
     * Log akses tidak sah.
     */
    private function logUnauthorizedAccess($user, string $action, $nodeId = null): void
    {
        activity()
            ->causedBy($user)
            ->withProperties([
                'user_id' => $user->id,
                'user_email' => $user->email,
                'action' => $action,
                'node_id' => $nodeId,
                'ip_address' => request()->ip(),
                'user_agent' => request()->userAgent()
            ])
            ->log('Percobaan akses tidak sah ke sistem manajemen node');
    }

    /**
     * Pesan error yang lebih professional.
     */
    private function getPermissionDeniedMessage(string $actionType): string
    {
        $messages = [
            'CREATE_NODE' => [
                'title' => 'Akses Ditolak - Pembuatan Node',
                'detail' => 'Hanya Administrator Utama (ID: 1) yang memiliki wewenang untuk menambahkan node baru ke dalam sistem.',
                'action' => 'Silakan hubungi Administrator Utama untuk permintaan pembuatan node.'
            ],
            'UPDATE_NODE' => [
                'title' => 'Akses Ditolak - Pengubahan Konfigurasi',
                'detail' => 'Modifikasi konfigurasi node hanya dapat dilakukan oleh Administrator Utama (ID: 1).',
                'action' => 'Hubungi Administrator Utama untuk perubahan konfigurasi yang diperlukan.'
            ],
            'DELETE_NODE' => [
                'title' => 'Akses Ditolak - Penghapusan Node',
                'detail' => 'Penghapusan node merupakan operasi kritis yang memerlukan otorisasi tingkat tertinggi.',
                'action' => 'Operasi ini memerlukan persetujuan dari Administrator Utama (ID: 1).'
            ]
        ];

        if (!isset($messages[$actionType])) {
            return 'Akses ditolak. Anda tidak memiliki izin untuk melakukan operasi ini.';
        }

        $message = $messages[$actionType];
        return implode(PHP_EOL, [
            "=== SISTEM KEAMANAN NODE MANAGEMENT ===",
            "",
            "🔒 {$message['title']}",
            "",
            "📋 Detail:",
            "   {$message['detail']}",
            "",
            "📌 Tindakan:",
            "   {$message['action']}",
            "",
            "👤 User ID: " . auth()->id(),
            "🕐 Waktu: " . now()->format('Y-m-d H:i:s'),
            "",
            "======================================"
        ]);
    }
}
EOF

chmod 644 "$REMOTE_PATH"

# Tampilkan pesan selesai dengan format yang rapi
echo ""
echo "=============================================="
echo " PROTEKSI NODE MANAGEMENT BERHASIL DIPASANG"
echo "=============================================="
echo ""
echo "📋 Status:          Berhasil diinstal"
echo "📁 File Target:     $REMOTE_PATH"
echo "📂 Backup File:     $BACKUP_PATH"
echo "🔐 Level Akses:     Restrictive"
echo "👤 Auth Required:   Administrator Utama (ID: 1)"
echo ""
echo "⚠️  PERHATIAN:"
echo "   - Hanya user dengan ID 1 yang dapat mengelola node"
echo "   - Semua aktivitas akan tercatat dalam sistem log"
echo "   - Percobaan akses tidak sah akan dilaporkan"
echo ""
echo "=============================================="
echo "✅ Instalasi selesai pada: $(date)"
echo "=============================================="
