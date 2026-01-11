/**
 * vAvA_core - HUD JavaScript
 * Gestion de l'interface NUI
 */

// ═══════════════════════════════════════════════════════════════════════════
// ÉTAT DE L'APPLICATION
// ═══════════════════════════════════════════════════════════════════════════

const App = {
    player: {
        health: 100,
        armor: 0,
        hunger: 100,
        thirst: 100,
        stress: 0,
        cash: 0,
        bank: 0
    },
    vehicle: {
        speed: 0,
        fuel: 100,
        engine: false,
        locked: false,
        lights: false
    },
    settings: {
        showMoney: true,
        showStatus: true,
        showVehicle: true
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// ÉLÉMENTS DOM
// ═══════════════════════════════════════════════════════════════════════════

const DOM = {
    // Status
    healthFill: document.getElementById('health-fill'),
    healthValue: document.getElementById('health-value'),
    armorFill: document.getElementById('armor-fill'),
    armorValue: document.getElementById('armor-value'),
    armorBar: document.getElementById('armor-bar'),
    hungerFill: document.getElementById('hunger-fill'),
    hungerValue: document.getElementById('hunger-value'),
    thirstFill: document.getElementById('thirst-fill'),
    thirstValue: document.getElementById('thirst-value'),
    stressFill: document.getElementById('stress-fill'),
    stressValue: document.getElementById('stress-value'),
    stressBar: document.getElementById('stress-bar'),
    healthBar: document.getElementById('health-bar'),
    hungerBar: document.getElementById('hunger-bar'),
    thirstBar: document.getElementById('thirst-bar'),
    
    // Money
    cashValue: document.getElementById('cash-value'),
    bankValue: document.getElementById('bank-value'),
    moneyHud: document.getElementById('money-hud'),
    
    // Player Info
    playerIdValue: document.getElementById('player-id-value'),
    playerJobValue: document.getElementById('player-job-value'),
    playerGradeValue: document.getElementById('player-grade-value'),
    playerInfoHud: document.getElementById('player-info-hud'),
    
    // Vehicle
    vehicleHud: document.getElementById('vehicle-hud'),
    speedValue: document.getElementById('speed-value'),
    speedCircle: document.getElementById('speed-circle'),
    fuelFill: document.getElementById('fuel-fill'),
    fuelValue: document.getElementById('fuel-value'),
    engineStatus: document.getElementById('engine-status'),
    lockStatus: document.getElementById('lock-status'),
    lightsStatus: document.getElementById('lights-status'),
    
    // Notifications
    notificationsContainer: document.getElementById('notifications-container'),
    
    // Progress
    progressContainer: document.getElementById('progress-container'),
    progressFill: document.getElementById('progress-fill'),
    progressLabel: document.getElementById('progress-label')
};

// ═══════════════════════════════════════════════════════════════════════════
// FONCTIONS UTILITAIRES
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Formate un nombre avec séparateurs de milliers
 */
function formatMoney(amount) {
    return '$' + amount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

/**
 * Limite une valeur entre min et max
 */
function clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
}

// ═══════════════════════════════════════════════════════════════════════════
// MISE À JOUR STATUS
// ═══════════════════════════════════════════════════════════════════════════

function updateStatus(data) {
    // Santé
    if (data.health !== undefined) {
        const health = clamp(data.health, 0, 100);
        DOM.healthFill.style.width = health + '%';
        DOM.healthValue.textContent = Math.round(health);
        
        if (health <= 20) {
            DOM.healthBar.classList.add('critical');
        } else {
            DOM.healthBar.classList.remove('critical');
        }
    }
    
    // Armure
    if (data.armor !== undefined) {
        const armor = clamp(data.armor, 0, 100);
        DOM.armorFill.style.width = armor + '%';
        DOM.armorValue.textContent = Math.round(armor);
        
        // Cacher si 0
        if (armor === 0) {
            DOM.armorBar.classList.add('hidden');
        } else {
            DOM.armorBar.classList.remove('hidden');
        }
    }
    
    // Faim
    if (data.hunger !== undefined) {
        const hunger = clamp(data.hunger, 0, 100);
        DOM.hungerFill.style.width = hunger + '%';
        DOM.hungerValue.textContent = Math.round(hunger);
        
        if (hunger <= 20) {
            DOM.hungerBar.classList.add('critical');
        } else {
            DOM.hungerBar.classList.remove('critical');
        }
    }
    
    // Soif
    if (data.thirst !== undefined) {
        const thirst = clamp(data.thirst, 0, 100);
        DOM.thirstFill.style.width = thirst + '%';
        DOM.thirstValue.textContent = Math.round(thirst);
        
        if (thirst <= 20) {
            DOM.thirstBar.classList.add('critical');
        } else {
            DOM.thirstBar.classList.remove('critical');
        }
    }
    
    // Stress
    if (data.stress !== undefined) {
        const stress = clamp(data.stress, 0, 100);
        DOM.stressFill.style.width = stress + '%';
        DOM.stressValue.textContent = Math.round(stress);
        
        // Afficher seulement si > 0
        if (stress > 0) {
            DOM.stressBar.classList.remove('hidden');
        } else {
            DOM.stressBar.classList.add('hidden');
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MISE À JOUR ARGENT
// ═══════════════════════════════════════════════════════════════════════════

function updateMoney(data) {
    const cashItem = DOM.cashValue.parentElement;
    const bankItem = DOM.bankValue.parentElement;
    
    // Cash
    if (data.cash !== undefined) {
        const oldCash = App.player.cash;
        App.player.cash = data.cash;
        
        if (data.cash > oldCash) {
            cashItem.classList.add('increase');
        } else if (data.cash < oldCash) {
            cashItem.classList.add('decrease');
        }
        
        setTimeout(() => {
            cashItem.classList.remove('increase', 'decrease');
        }, 500);
        
        DOM.cashValue.textContent = formatMoney(data.cash);
    }
    
    // Banque
    if (data.bank !== undefined) {
        const oldBank = App.player.bank;
        App.player.bank = data.bank;
        
        if (data.bank > oldBank) {
            bankItem.classList.add('increase');
        } else if (data.bank < oldBank) {
            bankItem.classList.add('decrease');
        }
        
        setTimeout(() => {
            bankItem.classList.remove('increase', 'decrease');
        }, 500);
        
        DOM.bankValue.textContent = formatMoney(data.bank);
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MISE À JOUR PLAYER INFO
// ═══════════════════════════════════════════════════════════════════════════

function updatePlayerInfo(data) {
    console.log('[vAvA_hud] updatePlayerInfo received:', data);
    
    // ID du joueur
    if (data.playerId !== undefined) {
        DOM.playerIdValue.textContent = data.playerId;
        console.log('[vAvA_hud] Updated playerId:', data.playerId);
    }
    
    // Job
    if (data.job !== undefined) {
        DOM.playerJobValue.textContent = data.job;
        console.log('[vAvA_hud] Updated job:', data.job);
    }
    
    // Grade
    if (data.grade !== undefined) {
        DOM.playerGradeValue.textContent = data.grade;
        console.log('[vAvA_hud] Updated grade:', data.grade);
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MISE À JOUR VÉHICULE
// ═══════════════════════════════════════════════════════════════════════════

function updateVehicle(data) {
    // Vitesse
    if (data.speed !== undefined) {
        const speed = Math.round(data.speed);
        DOM.speedValue.textContent = speed;
        
        // Calculer le stroke-dashoffset (314 = circonférence)
        const maxSpeed = 250;
        const progress = clamp(speed / maxSpeed, 0, 1);
        const offset = 314 - (314 * progress);
        DOM.speedCircle.style.strokeDashoffset = offset;
        
        // Couleur selon vitesse
        if (speed > 180) {
            DOM.speedCircle.style.stroke = '#e74c3c';
        } else if (speed > 120) {
            DOM.speedCircle.style.stroke = '#f39c12';
        } else {
            DOM.speedCircle.style.stroke = '#2ecc71';
        }
    }
    
    // Carburant
    if (data.fuel !== undefined) {
        const fuel = clamp(data.fuel, 0, 100);
        DOM.fuelFill.style.width = fuel + '%';
        DOM.fuelValue.textContent = Math.round(fuel) + '%';
        
        if (fuel <= 20) {
            DOM.fuelFill.classList.add('low');
        } else {
            DOM.fuelFill.classList.remove('low');
        }
    }
    
    // Moteur
    if (data.engine !== undefined) {
        DOM.engineStatus.textContent = data.engine ? 'ON' : 'OFF';
        DOM.engineStatus.style.color = data.engine ? '#2ecc71' : '#e74c3c';
    }
    
    // Verrou
    if (data.locked !== undefined) {
        DOM.lockStatus.textContent = data.locked ? '🔒' : '🔓';
    }
    
    // Phares
    if (data.lights !== undefined) {
        DOM.lightsStatus.textContent = data.lights ? 'ON' : 'OFF';
        DOM.lightsStatus.style.color = data.lights ? '#f39c12' : '#666';
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFICATIONS
// ═══════════════════════════════════════════════════════════════════════════

function showNotification(data) {
    const notification = document.createElement('div');
    notification.className = `notification ${data.type || 'info'}`;
    
    notification.innerHTML = `
        <div class="notification-icon"></div>
        <div class="notification-content">
            ${data.title ? `<div class="notification-title">${data.title}</div>` : ''}
            <div class="notification-message">${data.message}</div>
        </div>
    `;
    
    DOM.notificationsContainer.appendChild(notification);
    
    // Supprimer après durée
    const duration = data.duration || 5000;
    
    setTimeout(() => {
        notification.classList.add('fadeOut');
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, duration);
}

// ═══════════════════════════════════════════════════════════════════════════
// PROGRESS BAR
// ═══════════════════════════════════════════════════════════════════════════

function showProgress(data) {
    DOM.progressLabel.textContent = data.label || 'Chargement...';
    DOM.progressFill.style.width = '0%';
    DOM.progressContainer.classList.remove('hidden');
    
    let progress = 0;
    const duration = data.duration || 3000;
    const interval = 50;
    const increment = (interval / duration) * 100;
    
    const timer = setInterval(() => {
        progress += increment;
        DOM.progressFill.style.width = Math.min(progress, 100) + '%';
        
        if (progress >= 100) {
            clearInterval(timer);
            setTimeout(() => {
                DOM.progressContainer.classList.add('hidden');
            }, 200);
        }
    }, interval);
}

function hideProgress() {
    DOM.progressContainer.classList.add('hidden');
}

// ═══════════════════════════════════════════════════════════════════════════
// VISIBILITÉ HUD
// ═══════════════════════════════════════════════════════════════════════════

function toggleHud(data) {
    if (data.status !== undefined) {
        document.getElementById('status-hud').style.display = data.status ? 'flex' : 'none';
    }
    
    if (data.money !== undefined) {
        DOM.moneyHud.style.display = data.money ? 'flex' : 'none';
    }
    
    if (data.vehicle !== undefined) {
        if (data.vehicle) {
            DOM.vehicleHud.classList.remove('hidden');
        } else {
            DOM.vehicleHud.classList.add('hidden');
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// ÉCOUTEUR D'ÉVÉNEMENTS NUI
// ═══════════════════════════════════════════════════════════════════════════

window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch (data.action) {
        case 'updateStatus':
            updateStatus(data);
            break;
            
        case 'updateMoney':
            updateMoney(data);
            break;
            
        case 'updatePlayerInfo':
            updatePlayerInfo(data);
            break;
            
        case 'updateVehicle':
            updateVehicle(data);
            break;
            
        case 'showVehicleHud':
            DOM.vehicleHud.classList.remove('hidden');
            break;
            
        case 'hideVehicleHud':
            DOM.vehicleHud.classList.add('hidden');
            break;
            
        case 'notify':
            showNotification(data);
            break;
            
        case 'progress':
            showProgress(data);
            break;
            
        case 'hideProgress':
            hideProgress();
            break;
            
        case 'toggleHud':
            toggleHud(data);
            break;
            
        case 'hide':
            document.body.style.display = 'none';
            break;
            
        case 'show':
            document.body.style.display = 'block';
            break;
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// INITIALISATION
// ═══════════════════════════════════════════════════════════════════════════

document.addEventListener('DOMContentLoaded', function() {
    console.log('[vCore] HUD initialized');
    
    // Cacher le HUD véhicule par défaut
    DOM.vehicleHud.classList.add('hidden');
    
    // Cacher stress par défaut
    DOM.stressBar.classList.add('hidden');
});
