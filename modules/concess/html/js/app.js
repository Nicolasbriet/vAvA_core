/**
 * vAvA Core - Module Concessionnaire
 * Interface JavaScript
 */

// État de l'application
let vehicles = [];
let categories = {};
let isAdmin = false;
let playerJob = null;
let selectedVehicle = null;
let selectedCategory = 'all';
let adminVehicles = [];

// ================================
// INITIALISATION
// ================================

document.addEventListener('DOMContentLoaded', () => {
    // Éléments du DOM
    const app = document.getElementById('app');
    const adminPanel = document.getElementById('admin-panel');
    const closeBtn = document.getElementById('close-btn');
    const adminBtn = document.getElementById('admin-btn');
    const adminCloseBtn = document.getElementById('admin-close-btn');
    const searchInput = document.getElementById('search-input');
    const sortSelect = document.getElementById('sort-select');
    const rotateLeft = document.getElementById('rotate-left');
    const rotateRight = document.getElementById('rotate-right');
    const applyColors = document.getElementById('apply-colors');
    const liverySelect = document.getElementById('livery-select');
    const buyBtn = document.getElementById('buy-btn');

    // Event listeners
    closeBtn.addEventListener('click', closeNUI);
    adminBtn.addEventListener('click', openAdminPanel);
    adminCloseBtn.addEventListener('click', closeAdminPanel);
    searchInput.addEventListener('input', filterVehicles);
    sortSelect.addEventListener('change', filterVehicles);
    rotateLeft.addEventListener('click', () => rotateVehicle('left'));
    rotateRight.addEventListener('click', () => rotateVehicle('right'));
    applyColors.addEventListener('click', applyVehicleColors);
    liverySelect.addEventListener('change', changeLivery);
    buyBtn.addEventListener('click', buyVehicle);

    // Tabs admin
    document.querySelectorAll('.admin-tab').forEach(tab => {
        tab.addEventListener('click', () => switchAdminTab(tab.dataset.tab));
    });

    // Formulaire d'ajout
    document.getElementById('add-vehicle-form').addEventListener('submit', addVehicle);

    // Recherche admin
    document.getElementById('admin-search').addEventListener('input', filterAdminVehicles);

    // Écoute Escape
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            if (!adminPanel.classList.contains('hidden')) {
                closeAdminPanel();
            } else {
                closeNUI();
            }
        }
    });
});

// ================================
// COMMUNICATION NUI
// ================================

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'open':
            openNUI(data);
            break;
        case 'close':
            hideUI();
            break;
        case 'updateAdminVehicles':
            updateAdminVehiclesList(data.vehicles);
            break;
        case 'openAdmin':
            document.getElementById('app').classList.add('hidden');
            document.getElementById('admin-panel').classList.remove('hidden');
            fetchAdminVehicles();
            break;
    }
});

function fetchNUI(event, data = {}) {
    const resourceName = GetParentResourceName();
    console.log(`[Concess] fetchNUI: ${event} vers ressource: ${resourceName}`);
    return fetch(`https://${resourceName}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).then(resp => {
        console.log(`[Concess] Réponse reçue pour ${event}`);
        return resp.json();
    }).catch((err) => {
        console.error(`[Concess] Erreur fetch ${event}:`, err);
        return {};
    });
}

// ================================
// GESTION DE L'INTERFACE
// ================================

function openNUI(data) {
    vehicles = data.vehicles || [];
    categories = data.categories || {};
    isAdmin = data.isAdmin || false;
    playerJob = data.playerJob || null;

    document.getElementById('app').classList.remove('hidden');
    document.getElementById('admin-panel').classList.add('hidden');

    // Afficher le bouton admin si autorisé
    if (isAdmin) {
        document.getElementById('admin-btn').classList.remove('hidden');
    } else {
        document.getElementById('admin-btn').classList.add('hidden');
    }

    // Afficher le job du joueur
    document.getElementById('player-job').textContent = playerJob || 'Citoyen';

    // Générer les catégories
    generateCategories();

    // Afficher les véhicules
    filterVehicles();

    // Reset sélection
    selectedVehicle = null;
    updateDetailsPanel();
}

function hideUI() {
    console.log('[Concess] Masquage de l\'UI');
    document.getElementById('app').classList.add('hidden');
    document.getElementById('admin-panel').classList.add('hidden');
}

function closeNUI() {
    console.log('[Concess] closeNUI appelé');
    // Appeler le callback Lua AVANT de masquer l'UI
    fetchNUI('close').then(() => {
        console.log('[Concess] Callback close exécuté avec succès');
        hideUI();
    }).catch((err) => {
        console.error('[Concess] Erreur callback close:', err);
        // En cas d'erreur, masquer quand même l'UI
        hideUI();
    });
}

// ================================
// CATÉGORIES
// ================================

function generateCategories() {
    const list = document.getElementById('categories-list');
    list.innerHTML = '';

    // Catégorie "Tous"
    const allItem = createCategoryItem('all', 'Tous les véhicules', 'fa-car', vehicles.length);
    allItem.classList.add('active');
    list.appendChild(allItem);

    // Catégories disponibles
    const categoryIcons = {
        compacts: 'fa-car-side',
        sedans: 'fa-car',
        suvs: 'fa-truck',
        coupes: 'fa-car-rear',
        muscle: 'fa-car-side',
        sports: 'fa-car',
        super: 'fa-car',
        motorcycles: 'fa-motorcycle',
        offroad: 'fa-truck-monster',
        boats: 'fa-ship',
        helicopters: 'fa-helicopter',
        planes: 'fa-plane'
    };

    for (const cat in categories) {
        const count = vehicles.filter(v => v.category === cat).length;
        const icon = categoryIcons[cat] || 'fa-car';
        const item = createCategoryItem(cat, formatCategoryName(cat), icon, count);
        list.appendChild(item);
    }
}

function createCategoryItem(id, name, icon, count) {
    const item = document.createElement('div');
    item.className = 'category-item';
    item.dataset.category = id;
    item.innerHTML = `
        <i class="fas ${icon}"></i>
        <span>${name}</span>
        <span class="category-count">${count}</span>
    `;
    item.addEventListener('click', () => selectCategory(id));
    return item;
}

function selectCategory(category) {
    selectedCategory = category;
    
    document.querySelectorAll('.category-item').forEach(item => {
        item.classList.remove('active');
        if (item.dataset.category === category) {
            item.classList.add('active');
        }
    });

    filterVehicles();
}

function formatCategoryName(name) {
    const names = {
        compacts: 'Compactes',
        sedans: 'Berlines',
        suvs: 'SUVs',
        coupes: 'Coupés',
        muscle: 'Muscle',
        sports: 'Sport',
        super: 'Super',
        motorcycles: 'Motos',
        offroad: 'Tout-terrain',
        boats: 'Bateaux',
        helicopters: 'Hélicoptères',
        planes: 'Avions'
    };
    return names[name] || name.charAt(0).toUpperCase() + name.slice(1);
}

// ================================
// LISTE DES VÉHICULES
// ================================

function filterVehicles() {
    const search = document.getElementById('search-input').value.toLowerCase();
    const sort = document.getElementById('sort-select').value;

    let filtered = vehicles.filter(v => {
        const matchSearch = v.name.toLowerCase().includes(search) || v.model.toLowerCase().includes(search);
        const matchCategory = selectedCategory === 'all' || v.category === selectedCategory;
        return matchSearch && matchCategory;
    });

    // Tri
    switch (sort) {
        case 'name':
            filtered.sort((a, b) => a.name.localeCompare(b.name));
            break;
        case 'price-asc':
            filtered.sort((a, b) => a.price - b.price);
            break;
        case 'price-desc':
            filtered.sort((a, b) => b.price - a.price);
            break;
    }

    renderVehicles(filtered);
}

function renderVehicles(vehiclesList) {
    const grid = document.getElementById('vehicles-grid');
    grid.innerHTML = '';

    if (vehiclesList.length === 0) {
        grid.innerHTML = '<p style="color: rgba(255,255,255,0.5); text-align: center; grid-column: 1/-1;">Aucun véhicule trouvé</p>';
        return;
    }

    vehiclesList.forEach(vehicle => {
        const card = document.createElement('div');
        card.className = 'vehicle-card';
        if (selectedVehicle && selectedVehicle.model === vehicle.model) {
            card.classList.add('selected');
        }
        
        // Utiliser l'image par défaut si aucune image n'est définie
        const imageSrc = vehicle.image || 'img/default.svg';
        const priceToShow = vehicle.priceWithTax || vehicle.price;
        
        card.innerHTML = `
            <div class="vehicle-image">
                <img src="${imageSrc}" 
                     onerror="this.src='img/default.svg'"
                     alt="${vehicle.name}">
            </div>
            <div class="vehicle-name">${vehicle.name}</div>
            <div class="vehicle-card-price">$${formatNumber(priceToShow)}</div>
        `;
        
        card.addEventListener('click', () => selectVehicle(vehicle));
        grid.appendChild(card);
    });
}

function selectVehicle(vehicle) {
    selectedVehicle = vehicle;

    // Mettre à jour la sélection visuelle
    document.querySelectorAll('.vehicle-card').forEach(card => {
        card.classList.remove('selected');
    });
    event.currentTarget.classList.add('selected');

    // Mettre à jour le panel de détails
    updateDetailsPanel();

    // Envoyer au client pour preview
    fetchNUI('selectPreview', { model: vehicle.model });

    // Récupérer le nombre de livrées
    fetchNUI('getLiveryCount', {}).then(count => {
        updateLiverySelect(count);
    });
}

// ================================
// PANEL DE DÉTAILS
// ================================

function updateDetailsPanel() {
    const nameEl = document.getElementById('vehicle-name');
    const priceEl = document.getElementById('vehicle-price');
    const buyBtn = document.getElementById('buy-btn');

    if (selectedVehicle) {
        nameEl.textContent = selectedVehicle.name;
        
        // Afficher prix HT et TTC
        const basePrice = selectedVehicle.price || 0;
        const priceWithTax = selectedVehicle.priceWithTax || basePrice;
        const tax = priceWithTax - basePrice;
        
        priceEl.innerHTML = `
            <div style="font-size: 24px; font-weight: bold;">$${formatNumber(priceWithTax)}</div>
            <div style="font-size: 14px; color: #aaa; margin-top: 5px;">
                Prix HT: $${formatNumber(basePrice)} | Taxe: $${formatNumber(tax)}
            </div>
        `;
        buyBtn.disabled = false;
    } else {
        nameEl.textContent = 'Sélectionnez un véhicule';
        priceEl.textContent = '$0';
        buyBtn.disabled = true;
    }
}

function updateLiverySelect(count) {
    const select = document.getElementById('livery-select');
    const section = document.getElementById('livery-section');
    
    select.innerHTML = '<option value="-1">Aucune</option>';
    
    if (count > 0) {
        section.classList.remove('hidden');
        for (let i = 0; i < count; i++) {
            const option = document.createElement('option');
            option.value = i;
            option.textContent = `Livrée ${i + 1}`;
            select.appendChild(option);
        }
    } else {
        section.classList.add('hidden');
    }
}

// ================================
// ACTIONS SUR LE VÉHICULE
// ================================

function rotateVehicle(direction) {
    fetchNUI('rotatePreview', { direction });
}

function applyVehicleColors() {
    const primary = document.getElementById('primary-color').value;
    const secondary = document.getElementById('secondary-color').value;
    fetchNUI('changeColor', { primary, secondary });
}

function changeLivery() {
    const livery = document.getElementById('livery-select').value;
    fetchNUI('changeLivery', { livery: parseInt(livery) });
}

function buyVehicle() {
    if (!selectedVehicle) return;

    const payment = document.querySelector('input[name="payment"]:checked').value;
    const primary = document.getElementById('primary-color').value;
    const secondary = document.getElementById('secondary-color').value;
    const livery = document.getElementById('livery-select').value;

    fetchNUI('buyVehicle', {
        model: selectedVehicle.model,
        method: payment,
        primaryColor: parseInt(primary),
        secondaryColor: parseInt(secondary),
        livery: parseInt(livery)
    });
}

// ================================
// PANEL ADMIN
// ================================

function openAdminPanel() {
    document.getElementById('admin-panel').classList.remove('hidden');
    fetchAdminVehicles();
}

function closeAdminPanel() {
    document.getElementById('admin-panel').classList.add('hidden');
}

function switchAdminTab(tabId) {
    document.querySelectorAll('.admin-tab').forEach(tab => {
        tab.classList.remove('active');
        if (tab.dataset.tab === tabId) {
            tab.classList.add('active');
        }
    });

    document.querySelectorAll('.admin-tab-content').forEach(content => {
        content.classList.remove('active');
    });
    document.getElementById('tab-' + tabId).classList.add('active');
}

function fetchAdminVehicles() {
    fetchNUI('adminAction', { action: 'getVehiclesList' });
}

function updateAdminVehiclesList(vehiclesList) {
    adminVehicles = vehiclesList || [];
    filterAdminVehicles();
}

function filterAdminVehicles() {
    const search = document.getElementById('admin-search').value.toLowerCase();
    const list = document.getElementById('admin-vehicles-list');
    list.innerHTML = '';

    const filtered = adminVehicles.filter(v => 
        v.name.toLowerCase().includes(search) || 
        v.model.toLowerCase().includes(search)
    );

    filtered.forEach(vehicle => {
        const item = document.createElement('div');
        item.className = 'admin-vehicle-item';
        item.innerHTML = `
            <div class="admin-vehicle-info">
                <span class="admin-vehicle-name">${vehicle.name}</span>
                <span class="admin-vehicle-details">${vehicle.model} | ${formatCategoryName(vehicle.category)} | $${formatNumber(vehicle.price)}</span>
            </div>
            <div class="admin-vehicle-actions">
                <button class="edit-btn" onclick="editVehicle('${vehicle.model}')">
                    <i class="fas fa-edit"></i>
                </button>
                <button class="delete-btn" onclick="deleteVehicle('${vehicle.model}')">
                    <i class="fas fa-trash"></i>
                </button>
            </div>
        `;
        list.appendChild(item);
    });
}

function addVehicle(e) {
    e.preventDefault();

    const data = {
        action: 'addVehicle',
        name: document.getElementById('add-name').value,
        model: document.getElementById('add-model').value,
        category: document.getElementById('add-category').value,
        price: parseInt(document.getElementById('add-price').value),
        vehicleType: document.getElementById('add-vehicleType').value,
        job: document.getElementById('add-job').value,
        jobOnly: document.getElementById('add-jobOnly').checked
    };

    fetchNUI('adminAction', data);
    
    // Reset form
    e.target.reset();
    
    // Rafraîchir la liste
    setTimeout(fetchAdminVehicles, 500);
}

function editVehicle(model) {
    const vehicle = adminVehicles.find(v => v.model === model);
    if (!vehicle) return;

    // Remplir le formulaire avec les données du véhicule
    document.getElementById('add-name').value = vehicle.name;
    document.getElementById('add-model').value = vehicle.model;
    document.getElementById('add-category').value = vehicle.category;
    document.getElementById('add-price').value = vehicle.price;
    document.getElementById('add-vehicleType').value = vehicle.vehicleType || 'cars';
    document.getElementById('add-job').value = vehicle.job || '';
    document.getElementById('add-jobOnly').checked = vehicle.jobOnly || false;

    // Changer de tab
    switchAdminTab('add');
}

function deleteVehicle(model) {
    if (!confirm('Supprimer ce véhicule ?')) return;

    fetchNUI('adminAction', { action: 'deleteVehicle', vehicleId: model });
    setTimeout(fetchAdminVehicles, 500);
}

// ================================
// UTILITAIRES
// ================================

function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

function GetParentResourceName() {
    // Vérifier si la fonction native FiveM existe
    if (typeof window !== 'undefined' && window.GetParentResourceName && window.GetParentResourceName !== GetParentResourceName) {
        return window.GetParentResourceName();
    }
    // Le nom de la ressource est vAvA_concess, pas vAvA_core
    return 'vAvA_concess';
}
