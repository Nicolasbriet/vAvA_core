// vAvA Police Tablet - JavaScript

const Tablet = {
    isOpen: false,
    currentTab: 'search',

    init: function() {
        this.bindEvents();
        this.updateTime();
        setInterval(() => this.updateTime(), 1000);
    },

    bindEvents: function() {
        // Close button
        document.getElementById('closeBtn').addEventListener('click', () => {
            this.close();
        });

        // Navigation tabs
        document.querySelectorAll('.nav-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                this.switchTab(btn.dataset.tab);
            });
        });

        // Search person
        document.getElementById('searchPersonBtn').addEventListener('click', () => {
            this.searchPerson();
        });
        document.getElementById('searchPersonInput').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.searchPerson();
        });

        // Search vehicle
        document.getElementById('searchVehicleBtn').addEventListener('click', () => {
            this.searchVehicle();
        });
        document.getElementById('searchVehicleInput').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.searchVehicle();
        });

        // NUI Messages
        window.addEventListener('message', (event) => {
            const data = event.data;

            switch(data.action) {
                case 'openTablet':
                    this.open();
                    break;
                case 'closeTablet':
                    this.close();
                    break;
                case 'updateData':
                    this.updateData(data.data);
                    break;
            }
        });

        // ESC Key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.isOpen) {
                this.close();
            }
        });
    },

    open: function() {
        this.isOpen = true;
        document.getElementById('tablet').classList.add('active');
        this.loadAlerts();
        this.loadUnits();
    },

    close: function() {
        this.isOpen = false;
        document.getElementById('tablet').classList.remove('active');
        
        // Notify game
        fetch(`https://${GetParentResourceName()}/closeTablet`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    },

    switchTab: function(tabName) {
        this.currentTab = tabName;

        // Update nav buttons
        document.querySelectorAll('.nav-btn').forEach(btn => {
            btn.classList.remove('active');
        });
        document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');

        // Update panels
        document.querySelectorAll('.tab-panel').forEach(panel => {
            panel.classList.remove('active');
        });
        document.getElementById(tabName).classList.add('active');

        // Load data for tab
        if (tabName === 'alerts') {
            this.loadAlerts();
        } else if (tabName === 'units') {
            this.loadUnits();
        }
    },

    updateTime: function() {
        const now = new Date();
        const hours = String(now.getHours()).padStart(2, '0');
        const minutes = String(now.getMinutes()).padStart(2, '0');
        document.getElementById('currentTime').textContent = `${hours}:${minutes}`;
    },

    // ═══════════════════════════════════════════════════════════════════════
    // SEARCH PERSON
    // ═══════════════════════════════════════════════════════════════════════

    searchPerson: function() {
        const query = document.getElementById('searchPersonInput').value.trim();
        if (!query) return;

        fetch(`https://${GetParentResourceName()}/searchPerson`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ query: query })
        })
        .then(response => response.json())
        .then(data => {
            this.displayPersonResults(data);
        });
    },

    displayPersonResults: function(results) {
        const container = document.getElementById('personResults');
        
        if (!results || results.length === 0) {
            container.innerHTML = '<div class="empty-state"><div class="icon">🔍</div><p>Aucune personne trouvée</p></div>';
            return;
        }

        let html = '';
        results.forEach(person => {
            html += `
                <div class="result-item" onclick="Tablet.viewCriminalRecord('${person.citizenid}')">
                    <h3>${person.firstName} ${person.lastName}</h3>
                    <p>📅 Né(e) le: ${person.dateofbirth}</p>
                    <p>👤 Sexe: ${person.sex === 'm' ? 'Masculin' : 'Féminin'}</p>
                    <p>📱 Téléphone: ${person.phone || 'Non renseigné'}</p>
                    <p>💼 Emploi: ${person.job || 'Sans emploi'}</p>
                </div>
            `;
        });

        container.innerHTML = html;
    },

    viewCriminalRecord: function(citizenId) {
        fetch(`https://${GetParentResourceName()}/getCriminalRecord`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ citizenId: citizenId })
        })
        .then(response => response.json())
        .then(data => {
            this.displayCriminalRecord(data);
        });
    },

    displayCriminalRecord: function(records) {
        alert('Casier judiciaire: ' + (records.length > 0 ? `${records.length} infractions` : 'Vierge'));
    },

    // ═══════════════════════════════════════════════════════════════════════
    // SEARCH VEHICLE
    // ═══════════════════════════════════════════════════════════════════════

    searchVehicle: function() {
        const plate = document.getElementById('searchVehicleInput').value.trim().toUpperCase();
        if (!plate) return;

        fetch(`https://${GetParentResourceName()}/searchVehicle`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ plate: plate })
        })
        .then(response => response.json())
        .then(data => {
            this.displayVehicleResults(data);
        });
    },

    displayVehicleResults: function(vehicle) {
        const container = document.getElementById('vehicleResults');
        
        if (!vehicle) {
            container.innerHTML = '<div class="empty-state"><div class="icon">🚗</div><p>Véhicule non trouvé</p></div>';
            return;
        }

        container.innerHTML = `
            <div class="result-item">
                <h3>🚗 ${vehicle.plate}</h3>
                <p>📦 Modèle: ${vehicle.model}</p>
                <p>👤 Propriétaire: ${vehicle.owner}</p>
                <p>🆔 Citizen ID: ${vehicle.ownerid}</p>
            </div>
        `;
    },

    // ═══════════════════════════════════════════════════════════════════════
    // ALERTS
    // ═══════════════════════════════════════════════════════════════════════

    loadAlerts: function() {
        fetch(`https://${GetParentResourceName()}/getRecentAlerts`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        })
        .then(response => response.json())
        .then(data => {
            this.displayAlerts(data);
        });
    },

    displayAlerts: function(alerts) {
        const container = document.getElementById('alertsList');
        
        if (!alerts || alerts.length === 0) {
            container.innerHTML = '<div class="empty-state"><div class="icon">🚨</div><p>Aucune alerte active</p></div>';
            return;
        }

        let html = '';
        alerts.forEach(alert => {
            const time = new Date(alert.created_at).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
            
            html += `
                <div class="alert-item priority-${alert.priority}" onclick="Tablet.respondToAlert(${alert.id})">
                    <div class="alert-header">
                        <span class="alert-code">${alert.alert_code || 'ALERTE'}</span>
                        <span class="alert-time">${time}</span>
                    </div>
                    <div class="alert-message">${alert.message}</div>
                    <div class="alert-location">📍 ${alert.street || 'Localisation inconnue'}</div>
                </div>
            `;
        });

        container.innerHTML = html;
    },

    respondToAlert: function(alertId) {
        fetch(`https://${GetParentResourceName()}/respondToAlert`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ alertId: alertId })
        });
    },

    // ═══════════════════════════════════════════════════════════════════════
    // UNITS
    // ═══════════════════════════════════════════════════════════════════════

    loadUnits: function() {
        fetch(`https://${GetParentResourceName()}/getActiveUnits`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        })
        .then(response => response.json())
        .then(data => {
            this.displayUnits(data);
        });
    },

    displayUnits: function(units) {
        const container = document.getElementById('unitsList');
        
        if (!units || units.length === 0) {
            container.innerHTML = '<div class="empty-state"><div class="icon">👮</div><p>Aucune unité en service</p></div>';
            return;
        }

        let html = '';
        units.forEach(unit => {
            html += `
                <div class="unit-item">
                    <span class="unit-name">👮 ${unit.name}</span>
                    <span class="unit-status">EN SERVICE</span>
                </div>
            `;
        });

        container.innerHTML = html;
    },

    updateData: function(data) {
        if (data.alerts) this.displayAlerts(data.alerts);
        if (data.units) this.displayUnits(data.units);
    }
};

// Initialize on load
window.addEventListener('DOMContentLoaded', () => {
    Tablet.init();
});

// Helper to get resource name
function GetParentResourceName() {
    return 'vAvA_core';
}
