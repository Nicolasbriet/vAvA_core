/**
 * vAvA Core - Module Garage
 * Interface JavaScript
 */

let vehicles = [];
let garageName = '';
let isImpound = false;
let impoundPrice = 0;
let garages = {};

// ================================
// INITIALISATION
// ================================

document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('close-btn').addEventListener('click', closeNUI);
    document.getElementById('admin-close-btn').addEventListener('click', closeAdmin);
    document.getElementById('create-garage-form').addEventListener('submit', createGarage);

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            if (!document.getElementById('admin-panel').classList.contains('hidden')) {
                closeAdmin();
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
            openGarage(data);
            break;
        case 'close':
            hideUI();
            break;
        case 'openAdmin':
            openAdmin(data.garages);
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

// ================================
// INTERFACE GARAGE
// ================================

function openGarage(data) {
    vehicles = data.vehicles || [];
    garageName = data.garageName || 'Garage';
    isImpound = data.isImpound || false;
    impoundPrice = data.impoundPrice || 0;

    document.getElementById('app').classList.remove('hidden');
    document.getElementById('admin-panel').classList.add('hidden');

    // Mettre à jour le header
    const icon = document.getElementById('header-icon');
    const title = document.getElementById('garage-title');
    
    if (isImpound) {
        icon.className = 'fas fa-car-crash';
        icon.style.color = '#ef4444';
        document.getElementById('impound-info').classList.remove('hidden');
        document.getElementById('impound-price').textContent = impoundPrice;
    } else {
        icon.className = 'fas fa-warehouse';
        icon.style.color = '#4ade80';
        document.getElementById('impound-info').classList.add('hidden');
    }
    
    title.textContent = garageName;

    renderVehicles();
}

function renderVehicles() {
    const list = document.getElementById('vehicles-list');
    const noVehicles = document.getElementById('no-vehicles');
    
    list.innerHTML = '';

    if (vehicles.length === 0) {
        noVehicles.classList.remove('hidden');
        list.classList.add('hidden');
        return;
    }

    noVehicles.classList.add('hidden');
    list.classList.remove('hidden');

    vehicles.forEach(vehicle => {
        const card = document.createElement('div');
        card.className = 'vehicle-card';
        
        const icon = getVehicleIcon(vehicle.type);
        const fuel = Math.round(vehicle.fuel || 100);
        const engine = Math.round((vehicle.engine || 1000) / 10);
        const body = Math.round((vehicle.body || 1000) / 10);

        card.innerHTML = `
            <div class="vehicle-icon">
                <i class="fas ${icon}"></i>
            </div>
            <div class="vehicle-info">
                <div class="vehicle-name">${formatVehicleName(vehicle.vehicle)}</div>
                <div class="vehicle-plate">${vehicle.plate}</div>
            </div>
            <div class="vehicle-stats">
                <div class="stat">
                    <i class="fas fa-gas-pump stat-icon fuel"></i>
                    <span class="stat-value">${fuel}%</span>
                </div>
                <div class="stat">
                    <i class="fas fa-cog stat-icon engine"></i>
                    <span class="stat-value">${engine}%</span>
                </div>
                <div class="stat">
                    <i class="fas fa-car-side stat-icon body"></i>
                    <span class="stat-value">${body}%</span>
                </div>
            </div>
            <button class="spawn-btn" onclick="spawnVehicle('${vehicle.plate}')">
                <i class="fas fa-key"></i> Sortir
            </button>
        `;

        list.appendChild(card);
    });
}

function spawnVehicle(plate) {
    fetchNUI('spawnVehicle', { plate });
}

function getVehicleIcon(type) {
    const icons = {
        'car': 'fa-car',
        'boat': 'fa-ship',
        'helicopter': 'fa-helicopter',
        'plane': 'fa-plane'
    };
    return icons[type] || 'fa-car';
}

function formatVehicleName(model) {
    if (!model) return 'Véhicule';
    return model.charAt(0).toUpperCase() + model.slice(1).toLowerCase();
}

// ================================
// INTERFACE ADMIN
// ================================

function openAdmin(garagesData) {
    garages = garagesData || {};
    
    document.getElementById('app').classList.add('hidden');
    document.getElementById('admin-panel').classList.remove('hidden');

    renderGaragesList();
}

function renderGaragesList() {
    const list = document.getElementById('garages-list');
    list.innerHTML = '';

    const garageKeys = Object.keys(garages);

    if (garageKeys.length === 0) {
        list.innerHTML = '<p style="color: rgba(255,255,255,0.4); text-align: center;">Aucun garage</p>';
        return;
    }

    garageKeys.forEach(id => {
        const garage = garages[id];
        const item = document.createElement('div');
        item.className = 'garage-item';
        item.innerHTML = `
            <div class="garage-item-info">
                <span class="garage-item-name">${garage.label || id}</span>
                <span class="garage-item-id">${id} - ${garage.vehicleType || 'car'}</span>
            </div>
            <button class="delete-btn" onclick="deleteGarage('${id}')">
                <i class="fas fa-trash"></i>
            </button>
        `;
        list.appendChild(item);
    });
}

function createGarage(e) {
    e.preventDefault();

    const garageId = document.getElementById('garage-id').value.toLowerCase().replace(/\s+/g, '_');
    const label = document.getElementById('garage-label').value;
    const vehicleType = document.getElementById('garage-type').value;
    const showBlip = document.getElementById('garage-blip').checked;

    // Envoyer au serveur
    fetchNUI('createGarage', {
        garageId,
        label,
        vehicleType,
        showBlip
    });

    // Reset form
    e.target.reset();
    closeAdmin();
}

function deleteGarage(garageId) {
    if (!confirm('Supprimer ce garage ?')) return;
    
    fetchNUI('deleteGarage', { garageId });
    closeAdmin();
}

// ================================
// NAVIGATION
// ================================

function hideUI() {
    document.getElementById('app').classList.add('hidden');
    document.getElementById('admin-panel').classList.add('hidden');
}

function closeNUI() {
    fetchNUI('close');
    hideUI();
}

function closeAdmin() {
    document.getElementById('admin-panel').classList.add('hidden');
    document.getElementById('app').classList.remove('hidden');
}

function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'vAvA_core';
}
