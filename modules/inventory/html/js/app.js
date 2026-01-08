/**
 * vAvA Inventory - Application JavaScript
 * Gestion de l'interface NUI avec drag & drop amélioré
 */

// Images par défaut en base64 SVG
const DEFAULT_IMAGES = {
    default: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNhNzhjZmEiIHN0cm9rZS13aWR0aD0iMiI+PHJlY3QgeD0iMyIgeT0iMyIgd2lkdGg9IjE4IiBoZWlnaHQ9IjE4IiByeD0iMiIvPjxjaXJjbGUgY3g9IjguNSIgY3k9IjguNSIgcj0iMS41Ii8+PHBhdGggZD0ibTIxIDE1LTUtNUw1IDIxIi8+PC9zdmc+',
    bread: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSIjZjU5ZTBiIiBzdHJva2U9IiNiNDU0MDkiIHN0cm9rZS13aWR0aD0iMSI+PGVsbGlwc2UgY3g9IjEyIiBjeT0iMTQiIHJ4PSI5IiByeT0iNiIvPjxwYXRoIGQ9Ik0zIDE0VjhhOSA2IDAgMCAxIDE4IDB2NiIgZmlsbD0iI2ZiYmYyNCIvPjwvc3ZnPg==',
    water: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSIjMDZiNmQ0IiBzdHJva2U9IiMwODkxYjIiIHN0cm9rZS13aWR0aD0iMSI+PHBhdGggZD0iTTEyIDJjMCAwLTggNy00IDEyczQgMTAgNCAxMHM4LTQgNC0xMFMxMiAyIDEyIDJ6Ii8+PC9zdmc+',
    phone: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNhNzhjZmEiIHN0cm9rZS13aWR0aD0iMiI+PHJlY3QgeD0iNSIgeT0iMiIgd2lkdGg9IjE0IiBoZWlnaHQ9IjIwIiByeD0iMiIvPjxsaW5lIHgxPSIxMiIgeTE9IjE4IiB4Mj0iMTIuMDEiIHkyPSIxOCIvPjwvc3ZnPg==',
    money: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSIjMTBiOTgxIiBzdHJva2U9IiMwNTk2NjkiIHN0cm9rZS13aWR0aD0iMSI+PHJlY3QgeD0iMiIgeT0iNiIgd2lkdGg9IjIwIiBoZWlnaHQ9IjEyIiByeD0iMiIvPjxjaXJjbGUgY3g9IjEyIiBjeT0iMTIiIHI9IjMiIGZpbGw9IiMwNTk2NjkiLz48dGV4dCB4PSIxMiIgeT0iMTQiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZpbGw9IiMxMGI5ODEiIGZvbnQtc2l6ZT0iNiI+JDwvdGV4dD48L3N2Zz4=',
    id_card: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNmNTllMGIiIHN0cm9rZS13aWR0aD0iMiI+PHJlY3QgeD0iMiIgeT0iNCIgd2lkdGg9IjIwIiBoZWlnaHQ9IjE2IiByeD0iMiIvPjxjaXJjbGUgY3g9IjgiIGN5PSIxMCIgcj0iMiIvPjxwYXRoIGQ9Ik02IDE2aDRNMTQgMTBoNE0xNCAxNGg0Ii8+PC9zdmc+',
    bandage: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSIjZmVlMmUyIiBzdHJva2U9IiNlZjQ0NDQiIHN0cm9rZS13aWR0aD0iMSI+PHJlY3QgeD0iNCIgeT0iOCIgd2lkdGg9IjE2IiBoZWlnaHQ9IjgiIHJ4PSIyIi8+PGNpcmNsZSBjeD0iOSIgY3k9IjEyIiByPSIxIiBmaWxsPSIjZWY0NDQ0Ii8+PGNpcmNsZSBjeD0iMTUiIGN5PSIxMiIgcj0iMSIgZmlsbD0iI2VmNDQ0NCIvPjwvc3ZnPg==',
    lockpick: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiM5Y2EzYWYiIHN0cm9rZS13aWR0aD0iMiI+PHBhdGggZD0iTTIgMTBoMTVhMSAxIDAgMCAxIDEgMXYyYTEgMSAwIDAgMS0xIDFIMiIvPjxwYXRoIGQ9Ik02IDEwVjdNMTAgMTBWNk0xNCAxMFY3Ii8+PC9zdmc+',
    weapon: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNlZjQ0NDQiIHN0cm9rZS13aWR0aD0iMiI+PHBhdGggZD0iTTIgMTRsMiAyTDIwIDJsLTIgMkw2IDE0bC0yIDJ6Ii8+PHBhdGggZD0iTTQgMjBsNC00TTEyIDEybDQgNCIvPjwvc3ZnPg==',
    food: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSIjZjU5ZTBiIiBzdHJva2U9IiNiNDU0MDkiIHN0cm9rZS13aWR0aD0iMSI+PGNpcmNsZSBjeD0iMTIiIGN5PSIxMiIgcj0iOCIvPjxwYXRoIGQ9Ik0xMiA2djEyTTYgMTJoMTIiIHN0cm9rZT0iI2I0NTQwOSIvPjwvc3ZnPg==',
    drink: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSIjMDZiNmQ0IiBzdHJva2U9IiMwODkxYjIiIHN0cm9rZS13aWR0aD0iMSI+PHBhdGggZD0iTTggMmg4bC0yIDE4SDEwTDggMnoiLz48cGF0aCBkPSJNNiAyMmgxMiIgc3Ryb2tlLXdpZHRoPSIyIi8+PC9zdmc+',
    tool: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiM5Y2EzYWYiIHN0cm9rZS13aWR0aD0iMiI+PHBhdGggZD0iTTE0LjcgNi4zYTEgMSAwIDAgMCAwIDEuNGwtNSA1YTEgMSAwIDAgMC0xLjQgMGwtMi42LTIuNmExIDEgMCAwIDAtMS40IDBMMS43IDEyLjdsLTEuNC0xLjQgMy41LTMuNWExIDEgMCAwIDEgMS40IDBsMi42IDIuNiA1LTVhMSAxIDAgMCAxIDEuNCAweiIvPjwvc3ZnPg=='
};

function getItemImage(itemName, itemType) {
    const name = itemName?.toLowerCase() || 'default';
    // D'abord chercher par nom
    if (DEFAULT_IMAGES[name]) return DEFAULT_IMAGES[name];
    // Puis par type
    if (itemType && DEFAULT_IMAGES[itemType]) return DEFAULT_IMAGES[itemType];
    // Sinon default
    return DEFAULT_IMAGES.default;
}

const Inventory = {
    isOpen: false,
    items: [],
    hotbar: {},
    selectedItem: null,
    selectedSlot: null,
    maxSlots: 50,
    maxWeight: 120,
    currentWeight: 0,
    dragData: null,
    dragSourceSlot: null,
    
    // Initialisation
    init() {
        this.setupEventListeners();
        this.createSlots();
        this.createHotbarSlots();
        console.log('[vAvA_inventory] Interface initialisée');
    },
    
    // Créer les slots d'inventaire
    createSlots() {
        const grid = document.getElementById('inventory-grid');
        grid.innerHTML = '';
        
        for (let i = 1; i <= this.maxSlots; i++) {
            const slot = document.createElement('div');
            slot.className = 'inventory-slot';
            slot.dataset.slot = i;
            slot.draggable = true;
            
            slot.addEventListener('click', (e) => this.onSlotClick(i, e));
            slot.addEventListener('contextmenu', (e) => this.onSlotRightClick(i, e));
            slot.addEventListener('dragstart', (e) => this.onDragStart(i, e));
            slot.addEventListener('dragend', (e) => this.onDragEnd(e));
            slot.addEventListener('dragover', (e) => this.onDragOver(i, e));
            slot.addEventListener('dragleave', (e) => this.onDragLeave(e));
            slot.addEventListener('drop', (e) => this.onDrop(i, e));
            
            grid.appendChild(slot);
        }
        
        document.getElementById('max-slots').textContent = this.maxSlots;
    },
    
    // Créer les slots de hotbar
    createHotbarSlots() {
        const container = document.getElementById('inventory-hotbar-slots');
        container.innerHTML = '';
        
        for (let i = 1; i <= 5; i++) {
            const slot = document.createElement('div');
            slot.className = 'hotbar-slot';
            slot.dataset.slot = i;
            
            slot.innerHTML = `
                <span class="hotbar-key">${i}</span>
                <div class="hotbar-item"></div>
            `;
            
            slot.addEventListener('dragover', (e) => {
                e.preventDefault();
                slot.classList.add('drag-over');
            });
            
            slot.addEventListener('dragleave', () => {
                slot.classList.remove('drag-over');
            });
            
            slot.addEventListener('drop', (e) => {
                e.preventDefault();
                slot.classList.remove('drag-over');
                if (this.dragData) {
                    this.setHotbar(i, this.dragData);
                }
            });
            
            container.appendChild(slot);
        }
    },
    
    // Event listeners
    setupEventListeners() {
        // Fermer inventaire
        document.getElementById('close-inventory').addEventListener('click', () => this.close());
        document.querySelector('.inventory-backdrop').addEventListener('click', () => this.close());
        
        // Touche Escape
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.isOpen) {
                this.close();
            }
        });
        
        // Fermer menu contextuel au clic ailleurs
        document.addEventListener('click', (e) => {
            if (!e.target.closest('.context-menu')) {
                this.hideContextMenu();
            }
        });
        
        // Actions du menu contextuel
        document.querySelectorAll('.context-item').forEach(item => {
            item.addEventListener('click', (e) => {
                const action = e.currentTarget.dataset.action;
                this.handleContextAction(action);
                this.hideContextMenu();
            });
        });
        
        // Actions des boutons item
        document.querySelectorAll('.action-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const action = e.currentTarget.dataset.action;
                if (this.selectedItem) {
                    this.handleItemAction(action, this.selectedItem);
                }
            });
        });
        
        // Modal quantité
        document.querySelector('.modal-close').addEventListener('click', () => this.hideModal());
        document.querySelector('.modal-btn.cancel').addEventListener('click', () => this.hideModal());
        
        // Slider quantité
        const slider = document.getElementById('amount-slider');
        const input = document.getElementById('amount-input');
        
        slider.addEventListener('input', () => {
            input.value = slider.value;
        });
        
        input.addEventListener('input', () => {
            slider.value = input.value;
        });
        
        // Boutons quantité
        document.querySelectorAll('.amount-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const amount = parseInt(btn.dataset.amount);
                const current = parseInt(input.value) || 1;
                const max = parseInt(slider.max);
                const min = parseInt(slider.min);
                
                let newValue = current + amount;
                newValue = Math.max(min, Math.min(max, newValue));
                
                input.value = newValue;
                slider.value = newValue;
            });
        });
        
        // NUI message handler
        window.addEventListener('message', (event) => this.handleNUIMessage(event.data));
    },
    
    // Gestion des messages NUI
    handleNUIMessage(data) {
        switch (data.action) {
            case 'openInventory':
                this.open(data);
                break;
            case 'closeInventory':
                this.close(false);
                break;
            case 'updateInventory':
                this.updateItems(data.inventory);
                this.updateWeight(data.currentWeight);
                break;
            case 'updateHotbar':
                this.updateHotbar(data.hotbar);
                break;
        }
    },
    
    // Ouvrir l'inventaire
    open(data) {
        this.isOpen = true;
        this.items = data.inventory || [];
        this.hotbar = data.hotbar || {};
        this.maxSlots = data.maxSlots || 40;
        this.maxWeight = data.maxWeight || 100;
        this.currentWeight = data.currentWeight || 0;
        
        this.createSlots();
        this.renderItems();
        this.updateWeight(this.currentWeight);
        this.updateHotbar(this.hotbar);
        this.clearSelection();
        
        document.getElementById('inventory-container').classList.remove('hidden');
        document.getElementById('hotbar').classList.add('hidden');
    },
    
    // Fermer l'inventaire
    close(sendCallback = true) {
        this.isOpen = false;
        document.getElementById('inventory-container').classList.add('hidden');
        document.getElementById('hotbar').classList.remove('hidden');
        this.hideContextMenu();
        this.hideModal();
        
        if (sendCallback) {
            fetch('https://vAvA_inventory/closeInventory', {
                method: 'POST',
                body: JSON.stringify({})
            });
        }
    },
    
    // Afficher les items
    renderItems() {
        // Reset tous les slots
        document.querySelectorAll('.inventory-slot').forEach(slot => {
            slot.innerHTML = '';
            slot.classList.remove('weapon', 'selected');
        });
        
        let usedSlots = 0;
        
        this.items.forEach(item => {
            const slot = document.querySelector(`.inventory-slot[data-slot="${item.slot}"]`);
            if (slot) {
                usedSlots++;
                this.renderItemInSlot(slot, item);
            }
        });
        
        document.getElementById('used-slots').textContent = usedSlots;
    },
    
    // Afficher un item dans un slot
    renderItemInSlot(slot, item) {
        const isWeapon = item.type === 'weapon';
        const imgSrc = getItemImage(item.name, item.type);
        
        slot.innerHTML = `
            <img class="item-image" src="${imgSrc}" alt="${item.label}" draggable="false">
            ${item.amount > 1 ? `<span class="item-count">${this.formatNumber(item.amount)}</span>` : ''}
            <span class="item-weight">${(item.weight * item.amount).toFixed(1)}kg</span>
        `;
        
        if (isWeapon) {
            slot.classList.add('weapon');
        }
    },
    
    // Formater les grands nombres
    formatNumber(num) {
        if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
        if (num >= 1000) return (num / 1000).toFixed(1) + 'k';
        return num;
    },
    
    // Mettre à jour le poids
    updateWeight(weight) {
        this.currentWeight = weight;
        const percentage = (weight / this.maxWeight) * 100;
        const fill = document.getElementById('weight-fill');
        
        fill.style.width = `${Math.min(percentage, 100)}%`;
        fill.classList.remove('warning', 'danger');
        
        if (percentage >= 90) {
            fill.classList.add('danger');
        } else if (percentage >= 70) {
            fill.classList.add('warning');
        }
        
        document.getElementById('weight-text').textContent = 
            `${weight.toFixed(1)} / ${this.maxWeight} kg`;
    },
    
    // Mettre à jour la hotbar
    updateHotbar(hotbar) {
        this.hotbar = hotbar || {};
        
        // Hotbar en jeu
        document.querySelectorAll('#hotbar .hotbar-slot').forEach(slot => {
            const slotNum = parseInt(slot.dataset.slot);
            const itemContainer = slot.querySelector('.hotbar-item');
            const invSlot = hotbar[slotNum];
            const item = invSlot ? this.getItemBySlot(invSlot) : null;
            
            if (item) {
                const imgSrc = getItemImage(item.name, item.type);
                itemContainer.innerHTML = `
                    <img src="${imgSrc}" alt="${item.label}">
                    ${item.amount > 1 ? `<span class="item-count">${this.formatNumber(item.amount)}</span>` : ''}
                `;
            } else {
                itemContainer.innerHTML = '';
            }
        });
        
        // Hotbar dans l'inventaire
        document.querySelectorAll('#inventory-hotbar-slots .hotbar-slot').forEach(slot => {
            const slotNum = parseInt(slot.dataset.slot);
            const itemContainer = slot.querySelector('.hotbar-item');
            const invSlot = hotbar[slotNum];
            const item = invSlot ? this.getItemBySlot(invSlot) : null;
            
            if (item) {
                const imgSrc = getItemImage(item.name, item.type);
                itemContainer.innerHTML = `
                    <img src="${imgSrc}" alt="${item.label}">
                    ${item.amount > 1 ? `<span class="item-count">${this.formatNumber(item.amount)}</span>` : ''}
                `;
            } else {
                itemContainer.innerHTML = '';
            }
        });
    },
    
    updateItems(items) {
        this.items = items || [];
        this.renderItems();
    },
    
    // Click sur un slot
    onSlotClick(slotNum, event) {
        const item = this.getItemBySlot(slotNum);
        if (!item) {
            this.clearSelection();
            return;
        }
        
        this.selectItem(item, slotNum);
    },
    
    // Clic droit sur un slot
    onSlotRightClick(slotNum, event) {
        event.preventDefault();
        
        const item = this.getItemBySlot(slotNum);
        if (!item) return;
        
        this.selectItem(item, slotNum);
        this.showContextMenu(event.clientX, event.clientY);
    },
    
    // Sélectionner un item
    selectItem(item, slotNum) {
        document.querySelectorAll('.inventory-slot').forEach(s => s.classList.remove('selected'));
        
        const slot = document.querySelector(`.inventory-slot[data-slot="${slotNum}"]`);
        if (slot) slot.classList.add('selected');
        
        this.selectedItem = item;
        this.selectedSlot = slotNum;
        
        // Afficher les infos
        document.getElementById('item-name').textContent = item.label;
        document.getElementById('item-description').textContent = item.description || 'Aucune description';
        document.getElementById('item-weight').textContent = `${(item.weight * item.amount).toFixed(2)} kg`;
        document.getElementById('item-amount').textContent = this.formatNumber(item.amount);
        
        const preview = document.getElementById('preview-image');
        preview.src = getItemImage(item.name, item.type);
        
        document.getElementById('item-actions').classList.remove('hidden');
    },
    
    // Effacer la sélection
    clearSelection() {
        this.selectedItem = null;
        this.selectedSlot = null;
        
        document.querySelectorAll('.inventory-slot').forEach(s => s.classList.remove('selected'));
        document.getElementById('item-name').textContent = 'Sélectionnez un item';
        document.getElementById('item-description').textContent = '-';
        document.getElementById('item-weight').textContent = '-';
        document.getElementById('item-amount').textContent = '-';
        document.getElementById('preview-image').src = '';
        document.getElementById('item-actions').classList.add('hidden');
    },
    
    // Drag & Drop amélioré
    onDragStart(slotNum, event) {
        const item = this.getItemBySlot(slotNum);
        if (!item) {
            event.preventDefault();
            return;
        }
        
        this.dragData = item;
        this.dragSourceSlot = slotNum;
        
        const slot = event.target.closest('.inventory-slot');
        slot.classList.add('dragging');
        
        // Créer ghost image personnalisé
        const ghost = document.createElement('div');
        ghost.className = 'drag-ghost';
        ghost.innerHTML = `<img src="${getItemImage(item.name, item.type)}">`;
        ghost.style.cssText = 'position:fixed;top:-100px;left:-100px;width:50px;height:50px;pointer-events:none;opacity:0.8;z-index:9999;';
        document.body.appendChild(ghost);
        event.dataTransfer.setDragImage(ghost, 25, 25);
        event.dataTransfer.effectAllowed = 'move';
        
        setTimeout(() => ghost.remove(), 0);
    },
    
    onDragEnd(event) {
        this.dragData = null;
        this.dragSourceSlot = null;
        document.querySelectorAll('.inventory-slot').forEach(s => {
            s.classList.remove('dragging', 'drag-over', 'drag-target');
        });
    },
    
    onDragOver(slotNum, event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        
        if (this.dragData && slotNum !== this.dragSourceSlot) {
            const slot = event.target.closest('.inventory-slot');
            if (slot && !slot.classList.contains('drag-over')) {
                document.querySelectorAll('.inventory-slot').forEach(s => s.classList.remove('drag-over'));
                slot.classList.add('drag-over');
            }
        }
    },
    
    onDragLeave(event) {
        const slot = event.target.closest('.inventory-slot');
        if (slot) {
            slot.classList.remove('drag-over');
        }
    },
    
    onDrop(slotNum, event) {
        event.preventDefault();
        document.querySelectorAll('.inventory-slot').forEach(s => {
            s.classList.remove('drag-over', 'dragging');
        });
        
        if (!this.dragData || !this.dragSourceSlot) return;
        
        const fromSlot = this.dragSourceSlot;
        const toSlot = slotNum;
        
        if (fromSlot !== toSlot) {
            // Animation visuelle locale immédiate
            this.swapSlotsVisually(fromSlot, toSlot);
            // Envoyer au serveur
            this.moveItem(fromSlot, toSlot);
        }
        
        this.dragData = null;
        this.dragSourceSlot = null;
    },
    
    // Swap visuel immédiat pour feedback utilisateur
    swapSlotsVisually(fromSlot, toSlot) {
        const fromItem = this.getItemBySlot(fromSlot);
        const toItem = this.getItemBySlot(toSlot);
        
        // Mettre à jour le tableau local
        this.items = this.items.map(item => {
            if (item.slot === fromSlot) return { ...item, slot: toSlot };
            if (item.slot === toSlot) return { ...item, slot: fromSlot };
            return item;
        });
        
        // Re-render
        this.renderItems();
    },
    
    // Actions
    handleContextAction(action) {
        if (!this.selectedItem) return;
        
        switch (action) {
            case 'use':
                this.useItem(this.selectedItem);
                break;
            case 'give':
                this.showAmountModal('give');
                break;
            case 'drop':
                this.showAmountModal('drop');
                break;
            case 'split':
                if (this.selectedItem.amount > 1) {
                    this.showAmountModal('split');
                }
                break;
            case 'hotbar':
                // Assigner au premier slot libre
                for (let i = 1; i <= 5; i++) {
                    if (!this.hotbar[i]) {
                        this.setHotbar(i, this.selectedItem);
                        break;
                    }
                }
                break;
        }
    },
    
    handleItemAction(action, item) {
        switch (action) {
            case 'use':
                this.useItem(item);
                break;
            case 'give':
                this.showAmountModal('give');
                break;
            case 'drop':
                this.showAmountModal('drop');
                break;
        }
    },
    
    // Utiliser un item
    useItem(item) {
        fetch('https://vAvA_inventory/useItem', {
            method: 'POST',
            body: JSON.stringify({ item: item })
        });
    },
    
    // Donner un item
    giveItem(item, amount) {
        fetch('https://vAvA_inventory/giveItem', {
            method: 'POST',
            body: JSON.stringify({ slot: item.slot, amount: amount })
        });
    },
    
    // Jeter un item
    dropItem(item, amount) {
        fetch('https://vAvA_inventory/dropItem', {
            method: 'POST',
            body: JSON.stringify({ slot: item.slot, amount: amount })
        });
    },
    
    // Déplacer un item
    moveItem(fromSlot, toSlot, amount) {
        fetch('https://vAvA_inventory/moveItem', {
            method: 'POST',
            body: JSON.stringify({ 
                fromSlot: fromSlot, 
                toSlot: toSlot, 
                amount: amount 
            })
        });
    },
    
    // Diviser un stack
    splitStack(item, amount) {
        fetch('https://vAvA_inventory/splitStack', {
            method: 'POST',
            body: JSON.stringify({ slot: item.slot, amount: amount })
        });
    },
    
    // Définir un raccourci hotbar
    setHotbar(slot, item) {
        if (!item || !item.slot) return; // Protection null
        
        fetch('https://vAvA_inventory/setHotbar', {
            method: 'POST',
            body: JSON.stringify({ slot: slot, itemSlot: item.slot })
        });
        
        this.hotbar[slot] = item.slot;
        this.updateHotbar(this.hotbar);
    },
    
    // Menu contextuel
    showContextMenu(x, y) {
        const menu = document.getElementById('context-menu');
        menu.style.left = `${x}px`;
        menu.style.top = `${y}px`;
        menu.classList.remove('hidden');
        
        // Ajuster si dépasse l'écran
        const rect = menu.getBoundingClientRect();
        if (rect.right > window.innerWidth) {
            menu.style.left = `${window.innerWidth - rect.width - 10}px`;
        }
        if (rect.bottom > window.innerHeight) {
            menu.style.top = `${window.innerHeight - rect.height - 10}px`;
        }
    },
    
    hideContextMenu() {
        document.getElementById('context-menu').classList.add('hidden');
    },
    
    // Modal quantité
    showAmountModal(action) {
        if (!this.selectedItem) return;
        
        const modal = document.getElementById('amount-modal');
        const slider = document.getElementById('amount-slider');
        const input = document.getElementById('amount-input');
        const title = document.getElementById('modal-title');
        
        const maxAmount = action === 'split' ? this.selectedItem.amount - 1 : this.selectedItem.amount;
        
        slider.max = maxAmount;
        slider.value = action === 'split' ? Math.floor(maxAmount / 2) : maxAmount;
        input.max = maxAmount;
        input.value = slider.value;
        
        switch (action) {
            case 'give':
                title.textContent = 'Quantité à donner';
                break;
            case 'drop':
                title.textContent = 'Quantité à jeter';
                break;
            case 'split':
                title.textContent = 'Quantité à séparer';
                break;
        }
        
        modal.classList.remove('hidden');
        
        // Configurer le bouton confirmer
        const confirmBtn = modal.querySelector('.modal-btn.confirm');
        confirmBtn.onclick = () => {
            const amount = parseInt(input.value) || 1;
            
            switch (action) {
                case 'give':
                    this.giveItem(this.selectedItem, amount);
                    break;
                case 'drop':
                    this.dropItem(this.selectedItem, amount);
                    break;
                case 'split':
                    this.splitStack(this.selectedItem, amount);
                    break;
            }
            
            this.hideModal();
        };
    },
    
    hideModal() {
        document.getElementById('amount-modal').classList.add('hidden');
    },
    
    // Helpers
    getItemBySlot(slotNum) {
        return this.items.find(item => item.slot === slotNum);
    },
    
    isWeapon(itemName) {
        return itemName.toLowerCase().startsWith('weapon_');
    }
};

// Initialiser au chargement
document.addEventListener('DOMContentLoaded', () => Inventory.init());
