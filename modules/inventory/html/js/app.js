/**
 * vAvA Inventory - Application JavaScript
 * Gestion de l'interface NUI
 */

const Inventory = {
    isOpen: false,
    items: [],
    hotbar: {},
    selectedItem: null,
    selectedSlot: null,
    maxSlots: 40,
    maxWeight: 100,
    currentWeight: 0,
    dragData: null,
    
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
        const isWeapon = this.isWeapon(item.name);
        
        slot.innerHTML = `
            <img class="item-image" src="img/items/${item.name.toLowerCase()}.png" 
                 onerror="this.src='img/items/default.png'" alt="${item.label}">
            ${item.amount > 1 ? `<span class="item-count">${item.amount}</span>` : ''}
            <span class="item-weight">${(item.weight * item.amount).toFixed(1)}kg</span>
        `;
        
        if (isWeapon) {
            slot.classList.add('weapon');
        }
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
            const item = hotbar[slotNum];
            
            if (item) {
                itemContainer.innerHTML = `
                    <img src="img/items/${item.name.toLowerCase()}.png" 
                         onerror="this.src='img/items/default.png'" alt="${item.label}">
                    ${item.amount > 1 ? `<span class="item-count">${item.amount}</span>` : ''}
                `;
            } else {
                itemContainer.innerHTML = '';
            }
        });
        
        // Hotbar dans l'inventaire
        document.querySelectorAll('#inventory-hotbar-slots .hotbar-slot').forEach(slot => {
            const slotNum = parseInt(slot.dataset.slot);
            const itemContainer = slot.querySelector('.hotbar-item');
            const item = hotbar[slotNum];
            
            if (item) {
                itemContainer.innerHTML = `
                    <img src="img/items/${item.name.toLowerCase()}.png" 
                         onerror="this.src='img/items/default.png'" alt="${item.label}">
                    ${item.amount > 1 ? `<span class="item-count">${item.amount}</span>` : ''}
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
        document.getElementById('item-amount').textContent = item.amount;
        
        const preview = document.getElementById('preview-image');
        preview.src = `img/items/${item.name.toLowerCase()}.png`;
        preview.onerror = () => preview.src = 'img/items/default.png';
        
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
    
    // Drag & Drop
    onDragStart(slotNum, event) {
        const item = this.getItemBySlot(slotNum);
        if (!item) {
            event.preventDefault();
            return;
        }
        
        this.dragData = item;
        event.target.classList.add('dragging');
        
        // Ghost image
        const ghost = document.createElement('div');
        ghost.className = 'drag-preview';
        ghost.innerHTML = `<img src="img/items/${item.name.toLowerCase()}.png" 
                               onerror="this.src='img/items/default.png'">`;
        document.body.appendChild(ghost);
        event.dataTransfer.setDragImage(ghost, 25, 25);
        
        setTimeout(() => ghost.remove(), 0);
    },
    
    onDragEnd(event) {
        this.dragData = null;
        document.querySelectorAll('.inventory-slot').forEach(s => {
            s.classList.remove('dragging', 'drag-over');
        });
    },
    
    onDragOver(slotNum, event) {
        event.preventDefault();
        if (this.dragData) {
            event.target.closest('.inventory-slot').classList.add('drag-over');
        }
    },
    
    onDragLeave(event) {
        event.target.closest('.inventory-slot')?.classList.remove('drag-over');
    },
    
    onDrop(slotNum, event) {
        event.preventDefault();
        const slot = event.target.closest('.inventory-slot');
        slot?.classList.remove('drag-over');
        
        if (!this.dragData) return;
        
        const fromSlot = this.dragData.slot;
        const toSlot = slotNum;
        
        if (fromSlot !== toSlot) {
            this.moveItem(fromSlot, toSlot, this.dragData.amount);
        }
        
        this.dragData = null;
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
        fetch('https://vAvA_inventory/setHotbar', {
            method: 'POST',
            body: JSON.stringify({ slot: slot, item: item })
        });
        
        this.hotbar[slot] = item;
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
