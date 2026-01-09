/* ========================================
   VAVA STATUS HUD - JAVASCRIPT
   Gestion dynamique de l'interface
   ======================================== */

let config = {
    position: 'bottom-right',
    showPercentage: true,
    hideWhenFull: false,
    animations: true,
    glowEffect: true
};

let currentHunger = 100;
let currentThirst = 100;
let isVisible = false;

/* ========================================
   INITIALIZATION
   ======================================== */

window.addEventListener('DOMContentLoaded', () => {
    console.log('[vAvA Status HUD] Interface chargée');
    
    // Attendre les messages NUI
    window.addEventListener('message', handleNUIMessage);
});

/* ========================================
   NUI MESSAGE HANDLER
   ======================================== */

function handleNUIMessage(event) {
    const data = event.data;
    
    switch(data.type) {
        case 'init':
            initializeHUD(data.config);
            break;
            
        case 'update':
            updateStatus(data.hunger, data.thirst);
            break;
            
        case 'show':
            showHUD();
            break;
            
        case 'hide':
            hideHUD();
            break;
            
        case 'toggle':
            toggleHUD();
            break;
    }
}

/* ========================================
   INITIALIZATION
   ======================================== */

function initializeHUD(newConfig) {
    if (newConfig) {
        config = { ...config, ...newConfig };
    }
    
    // Appliquer la position
    const container = document.getElementById('status-hud');
    container.className = `status-container ${config.position}`;
    
    // Afficher/masquer les pourcentages
    const percentages = document.querySelectorAll('.status-percentage');
    percentages.forEach(p => {
        p.style.display = config.showPercentage ? 'block' : 'none';
    });
    
    // Afficher le HUD
    setTimeout(() => {
        showHUD();
    }, 500);
    
    console.log('[vAvA Status HUD] Initialisé avec config:', config);
}

/* ========================================
   UPDATE STATUS
   ======================================== */

function updateStatus(hunger, thirst) {
    currentHunger = Math.max(0, Math.min(100, hunger));
    currentThirst = Math.max(0, Math.min(100, thirst));
    
    // Mettre à jour les barres
    updateBar('hunger', currentHunger);
    updateBar('thirst', currentThirst);
    
    // Gérer le mode "hide when full"
    if (config.hideWhenFull) {
        if (currentHunger >= 100 && currentThirst >= 100) {
            hideHUD();
        } else {
            showHUD();
        }
    } else {
        if (!isVisible) {
            showHUD();
        }
    }
}

/* ========================================
   UPDATE BAR
   ======================================== */

function updateBar(type, value) {
    const bar = document.getElementById(`${type}-bar`);
    const percentage = document.getElementById(`${type}-percentage`);
    
    if (!bar || !percentage) return;
    
    // Mettre à jour la largeur avec animation
    bar.style.width = `${value}%`;
    
    // Mettre à jour le texte
    percentage.textContent = `${Math.round(value)}%`;
    
    // Gérer les classes de niveau
    bar.classList.remove('low', 'critical');
    
    if (value <= 20) {
        bar.classList.add('critical');
    } else if (value <= 40) {
        bar.classList.add('low');
    }
    
    // Ajouter un effet de pulse si la valeur est basse
    if (config.animations) {
        const item = bar.closest('.status-item');
        
        if (value <= 20) {
            item.style.animation = 'pulse-critical 0.5s infinite';
        } else if (value <= 40) {
            item.style.animation = 'pulse-warning 1s infinite';
        } else {
            item.style.animation = 'none';
        }
    }
    
    // Ajuster la couleur du pourcentage
    if (value <= 20) {
        percentage.style.color = '#FF0000';
    } else if (value <= 40) {
        percentage.style.color = '#FF4444';
    } else {
        percentage.style.color = '#FFFFFF';
    }
}

/* ========================================
   SHOW/HIDE HUD
   ======================================== */

function showHUD() {
    const container = document.getElementById('status-hud');
    container.classList.add('visible');
    isVisible = true;
}

function hideHUD() {
    const container = document.getElementById('status-hud');
    container.classList.remove('visible');
    isVisible = false;
}

function toggleHUD() {
    if (isVisible) {
        hideHUD();
    } else {
        showHUD();
    }
}

/* ========================================
   UTILITY FUNCTIONS
   ======================================== */

function setPosition(position) {
    config.position = position;
    const container = document.getElementById('status-hud');
    container.className = `status-container ${position}`;
    if (isVisible) {
        container.classList.add('visible');
    }
}

function setShowPercentage(show) {
    config.showPercentage = show;
    const percentages = document.querySelectorAll('.status-percentage');
    percentages.forEach(p => {
        p.style.display = show ? 'block' : 'none';
    });
}

function setHideWhenFull(hide) {
    config.hideWhenFull = hide;
    
    // Vérifier immédiatement
    if (hide && currentHunger >= 100 && currentThirst >= 100) {
        hideHUD();
    } else if (!hide && !isVisible) {
        showHUD();
    }
}

/* ========================================
   ANIMATIONS TEST (pour debug)
   ======================================== */

function testAnimation() {
    let value = 100;
    
    const interval = setInterval(() => {
        value -= 5;
        
        if (value < 0) {
            value = 100;
        }
        
        updateStatus(value, value);
    }, 200);
    
    // Arrêter après 10 secondes
    setTimeout(() => {
        clearInterval(interval);
        updateStatus(100, 100);
    }, 10000);
}

// Exposer pour debug
window.vavaStatusHUD = {
    updateStatus,
    showHUD,
    hideHUD,
    toggleHUD,
    setPosition,
    setShowPercentage,
    setHideWhenFull,
    testAnimation
};

console.log('[vAvA Status HUD] JavaScript chargé - window.vavaStatusHUD disponible pour debug');
