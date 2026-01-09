/**
 * vAvA Inventory - Admin Panel
 * Gestion admin des items et inventaires
 */

let currentTab = 'items';
let allItems = [];
let allPlayers = [];
let currentEditItem = null;
let selectedPlayer = null;

// ═══════════════════════════════════════════════════════════════════════════
// INITIALISATION
// ═══════════════════════════════════════════════════════════════════════════

window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch(data.action) {
        case 'openAdmin':
            openAdmin(data.items, data.players);
            break;
        case 'closeAdmin':
            closeAdmin();
            break;
        case 'updateItems':
            allItems = data.items;
            renderItems();
            break;
        case 'updatePlayers':
            allPlayers = data.players;
            renderPlayers();
            break;
    }
});

// ESC pour fermer
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        const modals = document.querySelectorAll('.modal:not(.hidden)');
        if (modals.length > 0) {
            modals.forEach(modal => modal.classList.add('hidden'));
        } else {
            closeAdmin();
        }
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// OUVERTURE/FERMETURE
// ═══════════════════════════════════════════════════════════════════════════

function openAdmin(items, players) {
    allItems = items || [];
    allPlayers = players || [];
    
    document.getElementById('admin-panel').classList.remove('hidden');
    renderItems();
    renderPlayers();
}

function closeAdmin() {
    document.getElementById('admin-panel').classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/closeAdmin`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({})
    });
}

// ═══════════════════════════════════════════════════════════════════════════
// NAVIGATION
// ═══════════════════════════════════════════════════════════════════════════

document.querySelectorAll('.nav-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const tab = btn.getAttribute('data-tab');
        switchTab(tab);
    });
});

function switchTab(tab) {
    currentTab = tab;
    
    // Update nav buttons
    document.querySelectorAll('.nav-btn').forEach(btn => {
        btn.classList.remove('active');
        if (btn.getAttribute('data-tab') === tab) {
            btn.classList.add('active');
        }
    });
    
    // Update tabs
    document.querySelectorAll('.admin-tab').forEach(t => {
        t.classList.remove('active');
    });
    document.getElementById(`tab-${tab}`).classList.add('active');
    
    // Charger les données selon le tab
    if (tab === 'items') renderItems();
    else if (tab === 'players') renderPlayers();
    else if (tab === 'logs') loadLogs();
}

// ═══════════════════════════════════════════════════════════════════════════
// ITEMS
// ═══════════════════════════════════════════════════════════════════════════

function renderItems() {
    const grid = document.getElementById('items-grid');
    const searchTerm = document.getElementById('search-items')?.value.toLowerCase() || '';
    
    const filteredItems = allItems.filter(item => 
        item.name.toLowerCase().includes(searchTerm) ||
        item.label.toLowerCase().includes(searchTerm)
    );
    
    grid.innerHTML = filteredItems.map(item => `
        <div class="item-card" data-item="${item.name}">
            <div class="item-card-header">
                <div>
                    <div class="item-card-title">${item.label}</div>
                    <div class="item-card-id">${item.name}</div>
                </div>
                <div class="item-card-actions">
                    <button class="item-card-btn edit" onclick="editItem('${item.name}')">
                        <i class="fas fa-edit"></i>
                    </button>
                    <button class="item-card-btn delete" onclick="deleteItem('${item.name}')">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            </div>
            <div class="item-card-info">
                <div class="item-info-row">
                    <span class="item-info-label">Type:</span>
                    <span class="item-type-badge ${item.type}">${item.type}</span>
                </div>
                <div class="item-info-row">
                    <span class="item-info-label">Poids:</span>
                    <span class="item-info-value">${item.weight} kg</span>
                </div>
                <div class="item-info-row">
                    <span class="item-info-label">Stack:</span>
                    <span class="item-info-value">${item.max_stack}</span>
                </div>
            </div>
        </div>
    `).join('');
}

// Créer un item
document.getElementById('create-item')?.addEventListener('click', () => {
    currentEditItem = null;
    document.getElementById('item-modal-title').querySelector('span').textContent = 'Créer un item';
    document.getElementById('item-form').reset();
    document.getElementById('item-modal').classList.remove('hidden');
});

// Éditer un item
function editItem(itemName) {
    const item = allItems.find(i => i.name === itemName);
    if (!item) return;
    
    currentEditItem = item;
    document.getElementById('item-modal-title').querySelector('span').textContent = 'Modifier un item';
    
    document.getElementById('item-name-input').value = item.name;
    document.getElementById('item-label-input').value = item.label;
    document.getElementById('item-weight-input').value = item.weight;
    document.getElementById('item-stack-input').value = item.max_stack;
    document.getElementById('item-type-input').value = item.type;
    
    if (item.weapon_hash) {
        document.getElementById('item-weapon-hash-input').value = item.weapon_hash;
    }
    
    document.getElementById('item-modal').classList.remove('hidden');
}

// Sauvegarder item
document.getElementById('save-item')?.addEventListener('click', () => {
    const itemData = {
        name: document.getElementById('item-name-input').value,
        label: document.getElementById('item-label-input').value,
        weight: parseFloat(document.getElementById('item-weight-input').value),
        max_stack: parseInt(document.getElementById('item-stack-input').value),
        type: document.getElementById('item-type-input').value,
        weapon_hash: document.getElementById('item-weapon-hash-input').value || null
    };
    
    if (!itemData.name || !itemData.label) {
        alert('Veuillez remplir tous les champs requis');
        return;
    }
    
    fetch(`https://${GetParentResourceName()}/saveItem`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
            item: itemData,
            isNew: !currentEditItem
        })
    });
    
    document.getElementById('item-modal').classList.add('hidden');
});

// Supprimer item
function deleteItem(itemName) {
    if (!confirm(`Supprimer l'item "${itemName}" ?`)) return;
    
    fetch(`https://${GetParentResourceName()}/deleteItem`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ itemName })
    });
}

// Recherche items
document.getElementById('search-items')?.addEventListener('input', renderItems);

// ═══════════════════════════════════════════════════════════════════════════
// JOUEURS
// ═══════════════════════════════════════════════════════════════════════════

function renderPlayers() {
    const list = document.getElementById('players-list');
    const searchTerm = document.getElementById('search-players')?.value.toLowerCase() || '';
    
    const filteredPlayers = allPlayers.filter(p => 
        p.name.toLowerCase().includes(searchTerm) ||
        p.id.toString().includes(searchTerm)
    );
    
    list.innerHTML = filteredPlayers.map(player => `
        <div class="player-card" onclick="openPlayerInventory(${player.id})">
            <div class="player-info">
                <div class="player-avatar">
                    <i class="fas fa-user"></i>
                </div>
                <div class="player-details">
                    <h4>${player.name}</h4>
                    <p>ID: ${player.id} • ${player.identifier}</p>
                </div>
            </div>
            <div class="player-stats">
                <div class="player-stat">
                    <div class="player-stat-value">${player.itemCount || 0}</div>
                    <div class="player-stat-label">Items</div>
                </div>
                <div class="player-stat">
                    <div class="player-stat-value">${player.weight || 0}</div>
                    <div class="player-stat-label">Poids</div>
                </div>
            </div>
        </div>
    `).join('');
}

function openPlayerInventory(playerId) {
    selectedPlayer = allPlayers.find(p => p.id === playerId);
    if (!selectedPlayer) return;
    
    document.getElementById('player-name').textContent = `Inventaire de ${selectedPlayer.name}`;
    
    fetch(`https://${GetParentResourceName()}/getPlayerInventory`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ playerId })
    });
    
    document.getElementById('player-inventory-modal').classList.remove('hidden');
}

// Recherche joueurs
document.getElementById('search-players')?.addEventListener('input', renderPlayers);

// ═══════════════════════════════════════════════════════════════════════════
// LOGS
// ═══════════════════════════════════════════════════════════════════════════

function loadLogs() {
    const filter = document.getElementById('log-filter')?.value || 'all';
    
    fetch(`https://${GetParentResourceName()}/getLogs`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ filter })
    });
}

// ═══════════════════════════════════════════════════════════════════════════
// MODALS
// ═══════════════════════════════════════════════════════════════════════════

// Fermer les modals
document.querySelectorAll('.modal-close, .modal-cancel').forEach(btn => {
    btn.addEventListener('click', () => {
        btn.closest('.modal').classList.add('hidden');
    });
});

// Affichage weapon hash selon type
document.getElementById('item-type-input')?.addEventListener('change', (e) => {
    const weaponGroup = document.querySelector('.weapon-only');
    if (e.target.value === 'weapon') {
        weaponGroup?.classList.remove('hidden');
    } else {
        weaponGroup?.classList.add('hidden');
    }
});

// Fermer au clic
document.getElementById('close-admin')?.addEventListener('click', closeAdmin);

// Helper
function GetParentResourceName() {
    return window.location.hostname === '' ? 'vAvA_core' : window.location.hostname;
}

console.log('[vAvA Inventory Admin] Chargé');
