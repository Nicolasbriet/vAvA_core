/**
 * vAvA Core - Module JobShop
 * Interface JavaScript
 */

let currentShopId = null;
let currentShop = null;
let modalCallback = null;

// ================================
// INITIALISATION
// ================================

document.addEventListener('DOMContentLoaded', () => {
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeNUI();
        }
    });
});

// ================================
// COMMUNICATION NUI
// ================================

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'openShop':
            openShopPanel(data.shop, data.items);
            break;
        case 'openBossMenu':
            openBossPanel(data.shop, data.items);
            break;
        case 'openAdminMenu':
            openAdminPanel(data.shops);
            break;
        case 'openStockMenu':
            openStockPanel(data.shop, data.items);
            break;
        case 'showCreateForm':
            showCreateForm();
            break;
        case 'showDeleteForm':
            showDeleteForm(data.shops);
            break;
        case 'close':
            hideAllPanels();
            break;
    }
});

function fetchNUI(event, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).then(resp => resp.json()).catch(() => ({}));
}

function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'vAvA_core';
}

// ================================
// GESTION DES PANELS
// ================================

function hideAllPanels() {
    document.getElementById('app').classList.add('hidden');
    document.getElementById('shop-panel').classList.add('hidden');
    document.getElementById('boss-panel').classList.add('hidden');
    document.getElementById('admin-panel').classList.add('hidden');
    document.getElementById('stock-panel').classList.add('hidden');
    document.getElementById('quantity-modal').classList.add('hidden');
    document.getElementById('create-form').classList.add('hidden');
    document.getElementById('shops-list').classList.add('hidden');
}

function showPanel(panelId) {
    hideAllPanels();
    document.getElementById('app').classList.remove('hidden');
    document.getElementById(panelId).classList.remove('hidden');
}

function closeNUI() {
    hideAllPanels();
    fetchNUI('close');
}

// ================================
// BOUTIQUE CLIENT
// ================================

function openShopPanel(shop, items) {
    currentShopId = shop.id;
    currentShop = shop;
    
    document.getElementById('shop-title').textContent = shop.name;
    
    const grid = document.getElementById('shop-items');
    grid.innerHTML = '';
    
    if (!items || items.length === 0) {
        grid.innerHTML = '<p style="color: rgba(255,255,255,0.5); text-align: center; grid-column: 1/-1;">Boutique vide</p>';
        showPanel('shop-panel');
        return;
    }
    
    items.forEach(item => {
        const stockClass = item.stock <= 0 ? 'empty' : (item.stock < 10 ? 'low' : '');
        
        const card = document.createElement('div');
        card.className = 'item-card';
        card.onclick = () => openQuantityModal(item);
        
        card.innerHTML = `
            <div class="item-icon">
                <i class="fas fa-box"></i>
            </div>
            <div class="item-name">${formatItemName(item.item_name)}</div>
            <div class="item-price">$${item.price}</div>
            <div class="item-stock ${stockClass}">Stock: ${item.stock}</div>
        `;
        
        grid.appendChild(card);
    });
    
    showPanel('shop-panel');
}

function openQuantityModal(item) {
    if (item.stock <= 0) {
        return;
    }
    
    document.getElementById('modal-title').textContent = `Acheter: ${formatItemName(item.item_name)}`;
    document.getElementById('modal-quantity').value = 1;
    document.getElementById('modal-quantity').max = item.stock;
    document.getElementById('quantity-modal').classList.remove('hidden');
    
    modalCallback = () => {
        const quantity = parseInt(document.getElementById('modal-quantity').value) || 1;
        fetchNUI('buyItem', {
            shopId: currentShopId,
            itemName: item.item_name,
            quantity: quantity
        });
    };
}

function confirmQuantity() {
    if (modalCallback) {
        modalCallback();
        modalCallback = null;
    }
    closeModal();
}

function closeModal() {
    document.getElementById('quantity-modal').classList.add('hidden');
    modalCallback = null;
}

// ================================
// MENU BOSS
// ================================

function openBossPanel(shop, items) {
    currentShopId = shop.id;
    currentShop = shop;
    
    document.getElementById('boss-title').textContent = `Gestion: ${shop.name}`;
    document.getElementById('shop-cash').textContent = shop.cash || 0;
    
    const list = document.getElementById('boss-items');
    list.innerHTML = '';
    
    if (!items || items.length === 0) {
        list.innerHTML = '<p style="color: rgba(255,255,255,0.5);">Aucun article configuré</p>';
    } else {
        items.forEach(item => {
            const row = document.createElement('div');
            row.className = 'item-row';
            row.innerHTML = `
                <div class="item-row-info">
                    <div class="item-row-name">${formatItemName(item.item_name)}</div>
                    <div class="item-row-details">Stock: ${item.stock} | ${item.enabled ? 'Actif' : 'Désactivé'}</div>
                </div>
                <div class="item-row-actions">
                    <input type="number" value="${item.price}" min="0" onchange="updatePrice('${item.item_name}', this.value)">
                    <button class="btn btn-sm ${item.enabled ? 'btn-danger' : 'btn-success'}" onclick="toggleItem('${item.item_name}', ${!item.enabled})">
                        <i class="fas ${item.enabled ? 'fa-eye-slash' : 'fa-eye'}"></i>
                    </button>
                </div>
            `;
            list.appendChild(row);
        });
    }
    
    showPanel('boss-panel');
}

function withdrawCash() {
    const amount = parseInt(document.getElementById('withdraw-amount').value) || 0;
    if (amount <= 0) return;
    
    fetchNUI('withdrawCash', {
        shopId: currentShopId,
        amount: amount
    });
    
    document.getElementById('withdraw-amount').value = '';
}

function updatePrice(itemName, price) {
    fetchNUI('setItemPrice', {
        shopId: currentShopId,
        itemName: itemName,
        price: parseInt(price) || 0
    });
}

function toggleItem(itemName, enabled) {
    fetchNUI('toggleItem', {
        shopId: currentShopId,
        itemName: itemName,
        enabled: enabled
    });
}

function addNewItem() {
    const name = document.getElementById('new-item-name').value;
    const price = parseInt(document.getElementById('new-item-price').value) || 0;
    const stock = parseInt(document.getElementById('new-item-stock').value) || 0;
    
    if (!name) return;
    
    fetchNUI('addItem', {
        shopId: currentShopId,
        itemName: name,
        price: price,
        stock: stock
    });
    
    document.getElementById('new-item-name').value = '';
    document.getElementById('new-item-price').value = '';
    document.getElementById('new-item-stock').value = '';
}

// ================================
// MENU ADMIN
// ================================

function openAdminPanel(shops) {
    document.getElementById('create-form').classList.add('hidden');
    document.getElementById('shops-list').classList.add('hidden');
    showPanel('admin-panel');
}

function showCreateForm() {
    document.getElementById('create-form').classList.remove('hidden');
    document.getElementById('shops-list').classList.add('hidden');
}

function hideCreateForm() {
    document.getElementById('create-form').classList.add('hidden');
}

function createShop() {
    const name = document.getElementById('create-name').value;
    const job = document.getElementById('create-job').value;
    const grade = parseInt(document.getElementById('create-grade').value) || 0;
    
    if (!name || !job) return;
    
    fetchNUI('createShop', {
        shopName: name,
        jobName: job,
        bossGrade: grade
    });
    
    document.getElementById('create-name').value = '';
    document.getElementById('create-job').value = '';
    document.getElementById('create-grade').value = '';
}

function listShops() {
    fetchNUI('adminAction', { action: 'list' });
    closeNUI();
}

function showDeleteForm(shops) {
    const container = document.getElementById('shops-container');
    container.innerHTML = '';
    
    const shopKeys = Object.keys(shops || {});
    
    if (shopKeys.length === 0) {
        container.innerHTML = '<p style="color: rgba(255,255,255,0.5);">Aucune boutique</p>';
    } else {
        shopKeys.forEach(id => {
            const shop = shops[id];
            const card = document.createElement('div');
            card.className = 'shop-card';
            card.innerHTML = `
                <div class="shop-card-info">
                    <h4>${shop.name}</h4>
                    <p>Job: ${shop.job} | Caisse: $${shop.cash || 0}</p>
                </div>
                <button class="btn btn-danger btn-sm" onclick="deleteShop(${shop.id})">
                    <i class="fas fa-trash"></i>
                </button>
            `;
            container.appendChild(card);
        });
    }
    
    document.getElementById('create-form').classList.add('hidden');
    document.getElementById('shops-list').classList.remove('hidden');
}

function deleteShop(shopId) {
    if (!confirm('Supprimer cette boutique ?')) return;
    
    fetchNUI('deleteShop', { shopId: shopId });
    closeNUI();
}

// ================================
// MENU STOCK (EMPLOYÉ)
// ================================

function openStockPanel(shop, items) {
    currentShopId = shop.id;
    currentShop = shop;
    
    document.getElementById('stock-title').textContent = `Approvisionner: ${shop.name}`;
    
    const list = document.getElementById('stock-items');
    list.innerHTML = '';
    
    if (!items || items.length === 0) {
        list.innerHTML = '<p style="color: rgba(255,255,255,0.5);">Aucun item à approvisionner</p>';
        showPanel('stock-panel');
        return;
    }
    
    items.forEach(item => {
        const row = document.createElement('div');
        row.className = 'item-row';
        row.innerHTML = `
            <div class="item-row-info">
                <div class="item-row-name">${formatItemName(item.name)}</div>
                <div class="item-row-details">Vous avez: ${item.playerAmount} | Stock boutique: ${item.shopStock}</div>
            </div>
            <div class="item-row-actions">
                <input type="number" id="stock-qty-${item.name}" value="1" min="1" max="${item.playerAmount}">
                <button class="btn btn-success btn-sm" onclick="addStock('${item.name}')">
                    <i class="fas fa-plus"></i> Ajouter
                </button>
            </div>
        `;
        list.appendChild(row);
    });
    
    showPanel('stock-panel');
}

function addStock(itemName) {
    const input = document.getElementById(`stock-qty-${itemName}`);
    const quantity = parseInt(input.value) || 1;
    
    fetchNUI('addStock', {
        shopId: currentShopId,
        itemName: itemName,
        quantity: quantity
    });
}

// ================================
// UTILITAIRES
// ================================

function formatItemName(name) {
    if (!name) return 'Item';
    return name.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
}
